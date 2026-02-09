import 'dart:async';

import 'package:logging/logging.dart';

import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/converters.dart';
import 'package:app/infra/database/drift_kinds.dart';
import 'package:app/infra/database/token_transformer.dart';
import 'package:rxdart/rxdart.dart';

/// Database service providing high-level operations for data ingestion.
/// Handles offline-first storage for DP-1 entities and relationships.
///
/// **Domain-only contract:** This service returns only **domain models**
/// ([Channel], [Playlist], [PlaylistItem]). It does not expose Drift Data
/// types ([ChannelData], [PlaylistData], [ItemData]) to callers. Conversion
/// from Data to domain happens inside this service.
class DatabaseService {
  /// Creates a DatabaseService.
  DatabaseService(this._db) {
    _log = Logger('DatabaseService');
  }

  final AppDatabase _db;
  late final Logger _log;

  // ===========================================================================
  // Watch operations (reactive streams)
  // ===========================================================================

  /// Watch channels as domain models.
  ///
  /// This is the Drift equivalent of the old repo's `watchChannelRows(...)`.
  Stream<List<Channel>> watchChannels({
    ChannelType? type,
    int? limit,
  }) {
    return _db
        .watchChannels(type: type?.index, limit: limit)
        .debounceTime(Duration(milliseconds: 300))
        .map(
          (rows) => rows.map(DatabaseConverters.channelDataToDomain).toList(),
        );
  }

  /// Watch playlists as domain models.
  ///
  /// This is the Drift equivalent of the old repo's `watchPlaylistRows(...)`.
  Stream<List<Playlist>> watchPlaylists({
    PlaylistType? type,
    String? channelId,
    String? ownerAddress,
    int? limit,
  }) {
    return _db
        .watchPlaylists(
          type: type?.index,
          channelId: channelId,
          ownerAddress: ownerAddress,
          limit: limit,
        )
        .debounceTime(Duration(milliseconds: 300))
        .map(
          (rows) =>
              rows.map(DatabaseConverters.playlistDataToDomainPreview).toList(),
        );
  }

  /// Watch playlist items as domain models.
  ///
  /// This watches the join table (`playlist_entries`) and emits the current
  /// ordered list of items for [playlistId]. The ordering is chosen based on the
  /// playlist's `sortMode`.
  Stream<List<PlaylistItem>> watchPlaylistItems(String playlistId) async* {
    final playlist = await getPlaylistById(playlistId);
    final sortMode = playlist?.sortMode ?? PlaylistSortMode.position;

    final Stream<List<ItemData>> stream;
    switch (sortMode) {
      case PlaylistSortMode.position:
        stream = _db.watchPlaylistItemsByPosition(playlistId);
      case PlaylistSortMode.provenance:
        stream = _db.watchPlaylistItemsByProvenance(playlistId);
    }

    yield* stream
        .debounceTime(Duration(milliseconds: 300))
        .map(
          (rows) =>
              rows.map(DatabaseConverters.itemDataToDomainPreview).toList(),
        );
  }

  /// Watch all playlist items batched by playlistId.
  ///
  /// Emits a map of {playlistId: [items]} whenever any item changes in any
  /// playlist. Prefer [watchPlaylistItems] for a single playlist to avoid
  /// subscribing to every playlist.
  ///
  /// Returns a map where each key is a playlistId and the value is the ordered
  /// list of items for that playlist (sorted by position or provenance based on
  /// each playlist's sortMode).
  Stream<Map<String, List<PlaylistItem>>> watchAllPlaylistItems() async* {
    // Get all playlists (including their sortMode)
    final allPlaylists = await getAllPlaylists();

    if (allPlaylists.isEmpty) {
      yield <String, List<PlaylistItem>>{};
      return;
    }

    // Build a map of streams for each playlist
    final playlistStreams = <String, Stream<List<ItemData>>>{};
    for (final playlist in allPlaylists) {
      final stream = playlist.sortMode == PlaylistSortMode.position
          ? _db.watchPlaylistItemsByPosition(playlist.id)
          : _db.watchPlaylistItemsByProvenance(playlist.id);
      playlistStreams[playlist.id] = stream;
    }

    // Use a controller to manually merge all streams
    final controller = StreamController<Map<String, List<PlaylistItem>>>();
    final cache = <String, List<PlaylistItem>>{};

    // Subscribe to all playlist streams
    final subscriptions = <StreamSubscription<List<ItemData>>>[];

    try {
      for (final entry in playlistStreams.entries) {
        final sub = entry.value.listen(
          (itemsData) {
            cache[entry.key] = itemsData
                .map(DatabaseConverters.itemDataToDomainPreview)
                .toList();
            if (!controller.isClosed) {
              controller.add(Map.from(cache));
            }
          },
          onError: (Object err) {
            if (!controller.isClosed) {
              controller.addError(err);
            }
          },
        );
        subscriptions.add(sub);
      }

      // Emit the stream
      yield* controller.stream;
    } finally {
      // Clean up subscriptions
      for (final sub in subscriptions) {
        await sub.cancel();
      }
      await controller.close();
    }
  }

  /// Watch playlist items for a channel (domain models).
  ///
  /// Emits when playlists, playlist_entries, or items for [channelId] change.
  Stream<List<PlaylistItem>> watchPlaylistItemsByChannel(
    String channelId, {
    int? limit,
    int? offset,
  }) {
    return _db
        .watchPlaylistItemsByChannel(
          channelId,
          limit: limit,
          offset: offset ?? 0,
        )
        .map(
          (rows) => rows.map(DatabaseConverters.itemDataToDomain).toList(),
        );
  }

  // ========== Channel Operations ==========

  /// Ingest a channel into the database.
  Future<void> ingestChannel(Channel channel) async {
    try {
      final companion = DatabaseConverters.channelToCompanion(channel);
      await _db.upsertChannel(companion);
      _log.info('Ingested channel: ${channel.id}');
    } catch (e, stack) {
      _log.severe('Failed to ingest channel ${channel.id}', e, stack);
      rethrow;
    }
  }

  /// Ingest multiple channels in a batch.
  Future<void> ingestChannels(List<Channel> channels) async {
    try {
      final companions = channels
          .map(DatabaseConverters.channelToCompanion)
          .toList();
      await _db.upsertChannels(companions);
      _log.info('Ingested ${channels.length} channels');

      // Checkpoint WAL to ensure data is written to main database
      await _db.checkpoint();
    } catch (e, stack) {
      _log.severe('Failed to ingest channels', e, stack);
      rethrow;
    }
  }

  /// Get all channels.
  Future<List<Channel>> getChannels() async {
    try {
      final data = await _db.getAllChannels();
      return data.map(DatabaseConverters.channelDataToDomain).toList();
    } catch (e, stack) {
      _log.severe('Failed to get channels', e, stack);
      rethrow;
    }
  }

  /// Get channels by type with optional pagination.
  Future<List<Channel>> getChannelsByType(
    ChannelType type, {
    int? limit,
    int offset = 0,
  }) async {
    try {
      final data = await _db.getChannelsByType(
        type.index,
        limit: limit,
        offset: offset,
      );
      return data.map(DatabaseConverters.channelDataToDomain).toList();
    } catch (e, stack) {
      _log.severe('Failed to get channels by type', e, stack);
      rethrow;
    }
  }

  /// Get channel by ID.
  Future<Channel?> getChannelById(String id) async {
    try {
      final data = await _db.getChannelById(id);
      return data != null ? DatabaseConverters.channelDataToDomain(data) : null;
    } catch (e, stack) {
      _log.severe('Failed to get channel $id', e, stack);
      rethrow;
    }
  }

  // ========== Playlist Operations ==========

  /// Ingest a playlist into the database.
  /// This handles both DP1 playlists and address-based playlists.
  Future<void> ingestPlaylist(Playlist playlist) async {
    try {
      final companion = DatabaseConverters.playlistToCompanion(playlist);
      await _db.upsertPlaylist(companion);
      _log.info(
        'Ingested playlist: ${playlist.id} | name: ${playlist.name} | type: ${playlist.type}',
      );
    } catch (e, stack) {
      _log.severe('Failed to ingest playlist ${playlist.id}', e, stack);
      rethrow;
    }
  }

  /// Ingest multiple playlists in a batch.
  Future<void> ingestPlaylists(List<Playlist> playlists) async {
    try {
      final companions = playlists
          .map(DatabaseConverters.playlistToCompanion)
          .toList();
      await _db.upsertPlaylists(companions);
      _log.info('Ingested ${playlists.length} playlists');

      // Checkpoint WAL to ensure data is written to main database
      await _db.checkpoint();
    } catch (e, stack) {
      _log.severe('Failed to ingest playlists', e, stack);
      rethrow;
    }
  }

  /// Get playlists for a channel.
  Future<List<Playlist>> getPlaylistsByChannel(String channelId) async {
    try {
      final data = await _db.getPlaylistsByChannel(channelId);
      return data.map(DatabaseConverters.playlistDataToDomainPreview).toList();
    } catch (e, stack) {
      _log.severe('Failed to get playlists for channel $channelId', e, stack);
      rethrow;
    }
  }

  /// Get playlist by ID.
  Future<Playlist?> getPlaylistById(String id) async {
    try {
      final data = await _db.getPlaylistById(id);
      return data != null
          ? DatabaseConverters.playlistDataToDomain(data)
          : null;
    } catch (e, stack) {
      _log.severe('Failed to get playlist $id', e, stack);
      rethrow;
    }
  }

  /// Get all playlists.
  Future<List<Playlist>> getAllPlaylists() async {
    try {
      final data = await _db.getAllPlaylists();
      final playlists = data
          .map(DatabaseConverters.playlistDataToDomain)
          .toList();
      _log.info('Retrieved ${playlists.length} playlists from database');
      return playlists;
    } catch (e, stack) {
      _log.severe('Failed to get all playlists', e, stack);
      rethrow;
    }
  }

  /// Get all address-based playlists.
  Future<List<Playlist>> getAddressPlaylists() async {
    try {
      final data = await _db.getAddressPlaylists();
      return data.map(DatabaseConverters.playlistDataToDomainPreview).toList();
    } catch (e, stack) {
      _log.severe('Failed to get address playlists', e, stack);
      rethrow;
    }
  }

  // ========== PlaylistItem Operations ==========

  /// Ingest a playlist item into the database.
  Future<void> ingestPlaylistItem(PlaylistItem item) async {
    try {
      final companion = DatabaseConverters.playlistItemToCompanion(item);
      await _db.upsertItem(companion);
      _log.fine('Ingested playlist item: ${item.id}');
    } catch (e, stack) {
      _log.severe('Failed to ingest playlist item ${item.id}', e, stack);
      rethrow;
    }
  }

  /// Ingest multiple playlist items in a batch.
  Future<void> ingestPlaylistItems(List<PlaylistItem> items) async {
    try {
      final companions = items
          .map(DatabaseConverters.playlistItemToCompanion)
          .toList();
      await _db.upsertItems(companions);
      _log.info('Ingested ${items.length} playlist items');
    } catch (e, stack) {
      _log.severe('Failed to ingest playlist items', e, stack);
      rethrow;
    }
  }

  /// Upsert enriched playlist items (thumbnails/artists only).
  ///
  /// This is used by the enrichment service to update items with indexer token
  /// data without touching playlist_entries. Wraps writes in a transaction for
  /// efficiency.
  Future<void> upsertPlaylistItemsEnriched(List<PlaylistItem> items) async {
    if (items.isEmpty) return;

    try {
      await _db.transaction(() async {
        final companions = items
            .map(DatabaseConverters.playlistItemToCompanion)
            .toList();
        await _db.upsertItems(companions);
      });

      _log.info('Upserted ${items.length} enriched playlist items');
    } catch (e, stack) {
      _log.severe('Failed to upsert enriched playlist items', e, stack);
      rethrow;
    }
  }

  /// Get playlist item by ID.
  Future<PlaylistItem?> getPlaylistItemById(String id) async {
    try {
      final data = await _db.getItemById(id);
      return data != null ? DatabaseConverters.itemDataToDomain(data) : null;
    } catch (e, stack) {
      _log.severe('Failed to get playlist item $id', e, stack);
      rethrow;
    }
  }

  /// Get items for a playlist.
  /// [limit] null = return all; [offset] null = 0.
  Future<List<PlaylistItem>> getPlaylistItems(
    String playlistId, {
    int? limit,
    int? offset,
  }) async {
    try {
      final playlist = await getPlaylistById(playlistId);
      if (playlist == null) {
        _log.warning('Playlist $playlistId not found');
        return [];
      }

      final data = playlist.sortMode == PlaylistSortMode.position
          ? await _db.getPlaylistItemsByPosition(
              playlistId,
              limit: limit,
              offset: offset,
            )
          : await _db.getPlaylistItemsByProvenance(
              playlistId,
              limit: limit,
              offset: offset,
            );

      return data.map(DatabaseConverters.itemDataToDomain).toList();
    } catch (e, stack) {
      _log.severe('Failed to get items for playlist $playlistId', e, stack);
      rethrow;
    }
  }

  /// Get playlist items for a channel (all playlists in channel, no ordering).
  /// [limit] null = return all; [offset] null = 0.
  Future<List<PlaylistItem>> getPlaylistItemsByChannel(
    String channelId, {
    int? limit,
    int? offset,
  }) async {
    try {
      final data = await _db.getPlaylistItemsByChannel(
        channelId,
        limit: limit,
        offset: offset ?? 0,
      );
      return data.map(DatabaseConverters.itemDataToDomain).toList();
    } catch (e, stack) {
      _log.severe(
        'Failed to get playlist items for channel $channelId',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Get all items from the database.
  ///
  /// Skips heavy JSON fields (provenance, reproduction, override, display, tokenData)
  /// to optimize list UI queries.
  Future<List<PlaylistItem>> getAllItems() async {
    try {
      final data = await _db.getAllItems();
      return data.map(DatabaseConverters.itemDataToDomainPreview).toList();
    } catch (e, stack) {
      _log.severe('Failed to get all items', e, stack);
      rethrow;
    }
  }

  /// Get items with optional [limit] and [offset] for paging.
  Future<List<PlaylistItem>> getItems({int? limit, int? offset}) async {
    try {
      final data = await _db.getItems(limit: limit, offset: offset);
      return data.map(DatabaseConverters.itemDataToDomainPreview).toList();
    } catch (e, stack) {
      _log.severe('Failed to get items', e, stack);
      rethrow;
    }
  }

  /// Debounce duration for [watchAllItems] stream (reduces emissions on rapid DB changes).
  static const Duration watchAllItemsDebounce = Duration(milliseconds: 300);

  /// Watch all items; emits when the items table changes.
  /// Debounced by [watchAllItemsDebounce]. Uses same preview converter as [getAllItems].
  Stream<List<PlaylistItem>> watchAllItems() {
    return _db
        .watchAllItems()
        .map(
          (rows) =>
              rows.map(DatabaseConverters.itemDataToDomainPreview).toList(),
        )
        .debounceTime(watchAllItemsDebounce);
  }

  /// Delete playlist item by ID.
  Future<void> deletePlaylistItem(String id) async {
    try {
      await _db.deleteItem(id);
      await _db.deletePlaylistEntriesByItem(id);
      _log.info('Deleted playlist item: $id');
    } catch (e, stack) {
      _log.severe('Failed to delete playlist item $id', e, stack);
      rethrow;
    }
  }

  /// Delete tokens by CIDs from a specific address-based playlist.
  ///
  /// This is used when processing change journal events (e.g. burn/transfer-out)
  /// to remove items from the owner's address playlist without touching other
  /// playlists.
  Future<void> deleteTokensByCids({
    required String address,
    required List<String> cids,
  }) async {
    if (cids.isEmpty) return;

    try {
      final normalizedAddress = address.toUpperCase();

      final playlists = await getAddressPlaylists();
      final addressPlaylist = playlists.firstWhere(
        (p) => p.ownerAddress?.toUpperCase() == normalizedAddress,
        orElse: () => throw Exception(
          'Address playlist not found for $address',
        ),
      );

      for (final cid in cids) {
        if (cid.isEmpty) continue;
        await _db.deletePlaylistEntry(
          playlistId: addressPlaylist.id,
          itemId: cid,
        );
      }

      await _db.updatePlaylistItemCount(addressPlaylist.id);
      await _db.checkpoint();

      _log.info(
        'Deleted ${cids.length} tokens from address playlist for $address',
      );
    } catch (e, stack) {
      _log.severe('Failed to delete tokens for address $address', e, stack);
      rethrow;
    }
  }

  /// Get cached token items by their item IDs (CIDs).
  ///
  /// This is useful for looking up existing cached items before deciding to
  /// refetch from the network.
  Future<List<PlaylistItem>> getTokensByCids(List<String> cids) async {
    if (cids.isEmpty) return [];
    try {
      final data = await _db.getItemsByIds(cids);
      return data.map(DatabaseConverters.itemDataToDomain).toList();
    } catch (e, stack) {
      _log.severe('Failed to get tokens by cids', e, stack);
      rethrow;
    }
  }

  // ========== Token Ingestion Operations ==========

  /// Ingest tokens from indexer for a specific address.
  /// This is used for address-based playlists.
  Future<void> ingestTokensForAddress({
    required String address,
    required List<AssetToken> tokens,
  }) async {
    try {
      final normalizedAddress = address.toUpperCase();

      // Find the address playlist
      final playlists = await getAddressPlaylists();
      final addressPlaylist = playlists.firstWhere(
        (p) => p.ownerAddress?.toUpperCase() == normalizedAddress,
        orElse: () => throw Exception(
          'Address playlist not found for $address',
        ),
      );

      // Filter tokens by owner
      final ownedTokens = TokenTransformer.filterTokensByOwner(
        tokens: tokens,
        ownerAddress: normalizedAddress,
      );

      if (ownedTokens.isEmpty) {
        _log.info('No tokens found for address $address');
        return;
      }

      // Transform tokens to playlist items
      final items = ownedTokens.map((token) {
        return TokenTransformer.assetTokenToPlaylistItem(
          token: token,
          ownerAddress: normalizedAddress,
        );
      }).toList();

      // Create playlist entries
      final entries = items.map((item) {
        final sortKeyUs = (item.provenance?['sortKeyUs'] as int?) ?? 0;

        return DatabaseConverters.createPlaylistEntry(
          playlistId: addressPlaylist.id,
          itemId: item.id,
          position: null, // No position for provenance-based sorting
          sortKeyUs: sortKeyUs,
        );
      }).toList();

      // Batch insert
      await ingestPlaylistItems(items);
      await _db.upsertPlaylistEntries(entries);
      await _db.updatePlaylistItemCount(addressPlaylist.id);

      // Checkpoint WAL to ensure data is written to main database
      await _db.checkpoint();

      _log.info(
        'Ingested ${items.length} tokens for address $address',
      );
    } catch (e, stack) {
      _log.severe('Failed to ingest tokens for address $address', e, stack);
      rethrow;
    }
  }

  /// Ingest DP1 playlist with bare items (no enrichment).
  ///
  /// Inserts playlist and playlist items/entries immediately without fetching
  /// indexer tokens. Items will have null thumbnailUrl/artists until enriched
  /// separately by the enrichment service.
  ///
  /// Wraps all writes in a single transaction.
  Future<void> ingestDP1PlaylistBare({
    required DP1Playlist playlist,
    required String baseUrl,
    required String? channelId,
  }) async {
    try {
      final domainPlaylist = DatabaseConverters.dp1PlaylistToDomain(
        playlist,
        baseUrl: baseUrl,
        channelId: channelId,
      );

      if (playlist.items.isEmpty) {
        // Single playlist write if no items
        await ingestPlaylist(domainPlaylist);
        _log.info('No items for DP1 playlist ${playlist.id}');
        return;
      }

      final playlistItems = <PlaylistItem>[];
      final entries = <PlaylistEntriesCompanion>[];

      for (var i = 0; i < playlist.items.length; i++) {
        final item = playlist.items[i];
        // Convert without token enrichment (thumbnail/artists will be null)
        final playlistItem = DatabaseConverters.dp1PlaylistItemToPlaylistItem(
          item,
          token: null,
        );
        playlistItems.add(playlistItem);
        entries.add(
          DatabaseConverters.createPlaylistEntry(
            playlistId: domainPlaylist.id,
            itemId: playlistItem.id,
            position: i,
            sortKeyUs: 0,
          ),
        );
      }

      // Wrap all writes in a single transaction to reduce lock churn.
      await _db.transaction(() async {
        final playlistCompanion = DatabaseConverters.playlistToCompanion(
          domainPlaylist,
        );
        await _db.upsertPlaylist(playlistCompanion);

        final itemCompanions = playlistItems
            .map(DatabaseConverters.playlistItemToCompanion)
            .toList();
        await _db.upsertItems(itemCompanions);

        await _db.upsertPlaylistEntries(entries);
        await _db.updatePlaylistItemCount(domainPlaylist.id);
      });

      _log.info(
        'Ingested bare DP1 playlist ${playlist.id} with ${playlistItems.length} items',
      );
    } catch (e, stack) {
      _log.severe(
        'Failed to ingest bare DP1 playlist ${playlist.id}',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Ingest DP1 playlist (wire model) into the database.
  ///
  /// Items are the main source of truth. When [tokens] is provided, each item
  /// is matched by CID and enriched with [thumbnailUrl] and DP1 [artists] from
  /// the token; when token is null for an item, those two fields remain null.
  ///
  /// [channelId] must be set when ingesting in channel context so
  /// getPlaylistItemsByChannel returns items.
  ///
  /// Wraps all writes in a single transaction to reduce lock churn and stream
  /// invalidations.
  Future<void> ingestDP1Playlist({
    required DP1Playlist playlist,
    required String baseUrl,
    String? channelId,
    List<AssetToken>? tokens,
  }) async {
    try {
      final domainPlaylist = DatabaseConverters.dp1PlaylistToDomain(
        playlist,
        baseUrl: baseUrl,
        channelId: channelId,
      );

      if (playlist.items.isEmpty) {
        // Single playlist write if no items
        await ingestPlaylist(domainPlaylist);
        _log.info('No items for DP1 playlist ${playlist.id}');
        return;
      }

      final tokensByCID = <String, AssetToken>{};
      if (tokens != null) {
        for (final token in tokens) {
          tokensByCID[token.cid] = token;
        }
      }

      final playlistItems = <PlaylistItem>[];
      final entries = <PlaylistEntriesCompanion>[];

      for (var i = 0; i < playlist.items.length; i++) {
        final item = playlist.items[i];
        final token = item.cid != null ? tokensByCID[item.cid!] : null;
        final playlistItem = DatabaseConverters.dp1PlaylistItemToPlaylistItem(
          item,
          token: token,
        );
        playlistItems.add(playlistItem);
        entries.add(
          DatabaseConverters.createPlaylistEntry(
            playlistId: domainPlaylist.id,
            itemId: playlistItem.id,
            position: i,
            sortKeyUs: 0,
          ),
        );
      }

      // Wrap all writes in a single transaction to reduce lock churn.
      await _db.transaction(() async {
        final playlistCompanion = DatabaseConverters.playlistToCompanion(
          domainPlaylist,
        );
        await _db.upsertPlaylist(playlistCompanion);

        final itemCompanions = playlistItems
            .map(DatabaseConverters.playlistItemToCompanion)
            .toList();
        await _db.upsertItems(itemCompanions);

        await _db.upsertPlaylistEntries(entries);
        await _db.updatePlaylistItemCount(domainPlaylist.id);
      });

      _log.info(
        'Ingested DP1 playlist ${playlist.id} with ${playlistItems.length} items',
      );
    } catch (e, stack) {
      _log.severe('Failed to ingest DP1 playlist ${playlist.id}', e, stack);
      rethrow;
    }
  }

  /// Get playlists from multiple baseUrls with pagination (domain only).
  /// Order: by baseUrls order, then by createdAt ASC within each baseUrl.
  Future<List<(Playlist, List<PlaylistItem>, String)>>
  getPlaylistRowsByBaseUrls({
    required List<String> baseUrls,
    int? kind,
    int? offset,
    int? limit,
  }) async {
    if (baseUrls.isEmpty) return [];

    final rows = await _db.getPlaylistsByBaseUrlsOrdered(
      baseUrls: baseUrls,
      type: kind ?? DriftPlaylistKind.dp1.value,
      offset: offset,
      limit: limit,
    );

    final result = <(Playlist, List<PlaylistItem>, String)>[];
    for (final row in rows) {
      final itemsData = row.sortMode == 1
          ? await _db.getPlaylistItemsByProvenance(row.id)
          : await _db.getPlaylistItemsByPosition(row.id);
      final playlist = DatabaseConverters.playlistDataToDomain(row);
      final items = itemsData.map(DatabaseConverters.itemDataToDomain).toList();
      result.add((playlist, items, row.baseUrl ?? ''));
    }
    return result;
  }

  /// Get channel by playlist ID (domain only).
  ///
  /// Returns a tuple of (channel, playlists list for UI, baseUrl).
  /// The playlists list uses light projection to skip heavy JSON fields.
  Future<(Channel, List<Playlist>, String)?> getChannelByPlaylistId(
    String playlistId,
  ) async {
    final playlistData = await _db.getPlaylistById(playlistId);
    if (playlistData == null || playlistData.channelId == null) return null;

    final baseUrl = playlistData.baseUrl ?? '';
    final channelId = playlistData.channelId!;

    final channelData = await _db.getChannelById(channelId);
    if (channelData == null) return null;

    final channelPlaylistsData = await _db.getPlaylistsByChannel(channelId);
    final channel = DatabaseConverters.channelDataToDomain(channelData);
    final playlists = channelPlaylistsData
        .map(DatabaseConverters.playlistDataToDomainPreview)
        .toList();
    return (channel, playlists, baseUrl);
  }

  /// Get playlists with items by channel/kind/baseUrl (domain only).
  Future<List<(Playlist, List<PlaylistItem>)>> getPlaylistRowsWithItems({
    String? channelId,
    int? kind,
    String? baseUrl,
  }) async {
    List<PlaylistData> rows;
    if (channelId != null) {
      rows = await _db.getPlaylistsByChannel(channelId);
    } else {
      rows = await _db.getAllPlaylists();
    }

    if (kind != null) {
      rows = rows.where((p) => p.type == kind).toList();
    }
    if (baseUrl != null) {
      rows = rows.where((p) => p.baseUrl == baseUrl).toList();
    }

    final result = <(Playlist, List<PlaylistItem>)>[];
    for (final row in rows) {
      final itemsData = row.sortMode == 1
          ? await _db.getPlaylistItemsByProvenance(row.id)
          : await _db.getPlaylistItemsByPosition(row.id);
      final playlist = DatabaseConverters.playlistDataToDomain(row);
      final items = itemsData.map(DatabaseConverters.itemDataToDomain).toList();
      result.add((playlist, items));
    }
    return result;
  }

  /// Delete a single playlist by ID and its entries.
  /// Matches old repo's deletePlaylistById / delete playlist from Drift.
  Future<void> deletePlaylistById(String playlistId) async {
    await _db.deletePlaylistEntries(playlistId);
    await (_db.delete(
      _db.playlists,
    )..where((p) => p.id.equals(playlistId))).go();
  }

  /// Delete all playlists of given kind and baseUrl.
  /// Matches old repo's deleteAllPlaylists(kind, baseUrl).
  Future<void> deleteAllPlaylistsByKindAndBaseUrl({
    required int kind,
    required String baseUrl,
  }) async {
    await _db.deletePlaylistsByTypeAndBaseUrl(type: kind, baseUrl: baseUrl);
  }

  /// Delete all channels of given kind and baseUrl.
  /// Matches old repo's deleteAllChannels(kind, baseUrl).
  Future<void> deleteAllChannelsByKindAndBaseUrl({
    required int type,
    required String baseUrl,
  }) async {
    await _db.deleteChannelsByTypeAndBaseUrl(type: type, baseUrl: baseUrl);
  }

  /// Clear all data from the database (for testing/reset).
  ///
  /// Uses a single batch so all deletes run in one transaction and the DB lock
  /// is held briefly. Using separate [transaction] + multiple [delete].go() can
  /// trigger "database has been locked" when watch streams (channels/playlists)
  /// try to read during the transaction.
  Future<void> clearAll() async {
    try {
      await _db.batch((batch) {
        // Child tables first (playlist_entries references playlists and items).
        batch.deleteAll(_db.playlistEntries);
        batch.deleteAll(_db.items);
        batch.deleteAll(_db.playlists);
        batch.deleteAll(_db.channels);
      });
      _log.info('Cleared all database data');
    } catch (e, stack) {
      _log.severe('Failed to clear database', e, stack);
      rethrow;
    }
  }

  /// Close the database connection.
  Future<void> close() async {
    await _db.close();
  }

  /// Force WAL checkpoint to persist pending changes to main database file.
  /// Useful after batch ingestion operations to ensure durability.
  Future<void> checkpoint() async {
    await _db.checkpoint();
  }

  /// Ingest DP1 channels (wire model) as domain [Channel] rows.
  ///
  /// DP1 feed services should only deal with DP1 wire models; conversion and
  /// persistence belong to the database layer.
  Future<void> ingestDP1ChannelsWire({
    required String baseUrl,
    required List<DP1Channel> channels,
  }) async {
    final domainChannels = channels.map((dp1) {
      return Channel(
        id: dp1.id,
        name: dp1.title,
        type: ChannelType.dp1,
        description: dp1.summary,
        baseUrl: baseUrl,
        slug: dp1.slug,
        curator: dp1.curator,
        coverImageUrl: dp1.coverImage,
        createdAt: dp1.created,
        updatedAt: dp1.created,
      );
    }).toList();

    await ingestChannels(domainChannels);
  }

  /// Ingest a DP1 playlist wire model into the database.
  ///
  /// When [fetchTokens] is provided and playlist items have CIDs, tokens are
  /// fetched and used to enrich items (thumbnail, artists). Otherwise no
  /// enrichment. Delegates to [ingestDP1Playlist].
  /// [channelId] must be set when ingesting in channel context so
  /// getPlaylistItemsByChannel returns items (playlists.channel_id in DB).
  Future<void> ingestDP1PlaylistWire({
    required String baseUrl,
    required DP1Playlist playlist,
    String? channelId,
    Future<List<AssetToken>?> Function(List<String> cids)? fetchTokens,
  }) async {
    List<AssetToken>? tokens;
    if (fetchTokens != null) {
      final cids = extractDP1ItemCids(playlist.items);
      if (cids.isNotEmpty) {
        try {
          tokens = await fetchTokens(cids);
        } on Exception catch (e) {
          _log.warning('Failed to fetch enrichment tokens: $e');
        }
      }
    }
    await ingestDP1Playlist(
      playlist: playlist,
      baseUrl: baseUrl,
      channelId: channelId,
      tokens: tokens,
    );
  }

  /// Extract CIDs from DP1 playlist items.
  ///
  /// DP1 items do not always contain a `cid` field directly; we compute it from
  /// provenance when possible.
  List<String> extractDP1ItemCids(List<DP1PlaylistItem> items) {
    return items
        .map((i) => i.cid)
        .where((cid) => cid != null)
        .cast<String>()
        .toList();
  }
}
