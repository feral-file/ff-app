import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/converters.dart';
import 'package:app/infra/database/favorite_history_snapshot.dart';
import 'package:app/infra/database/token_transformer.dart';
import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';
import 'package:wallet/wallet.dart' as wallet;

// ignore_for_file: lines_longer_than_80_chars // Reason: drift query docs and SQL-focused comments can exceed 80 chars.

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

  /// Enrichment status: metadata not resolved yet.
  static const int enrichmentStatusPending = 0;

  /// Enrichment status: metadata resolved successfully.
  static const int enrichmentStatusEnriched = 1;

  /// Enrichment status: enrichment failed and should be skipped for now.
  static const int enrichmentStatusFailed = 2;

  // ===========================================================================
  // Watch operations (reactive streams)
  // ===========================================================================

  /// Watch channels by type, filtered to those with at least one playlist
  /// entry. Emits when channels, playlists, or playlist_entries change.
  /// Use for Me section so it reacts to address remove / unfavorite.
  Stream<List<Channel>> watchChannelsByType(
    ChannelType type, {
    int? limit,
    int offset = 0,
  }) {
    return _db
        .watchChannelsByType(type.index, limit: limit, offset: offset)
        .debounceTime(const Duration(milliseconds: 300))
        .map(
          (rows) => rows.map(DatabaseConverters.channelDataToDomain).toList(),
        );
  }

  /// All channels (for resolving playlist → publisher / section titles).
  ///
  /// Ordered like `watchChannels` on the database: publisher_id, sort_order,
  /// id.
  Stream<List<Channel>> watchAllChannels() {
    return _db
        .watchChannels()
        .debounceTime(const Duration(milliseconds: 300))
        .map(
          (rows) => rows.map(DatabaseConverters.channelDataToDomain).toList(),
        );
  }

  /// Publisher id → display name; updates when publishers are ingested.
  Stream<Map<int, String>> watchPublisherTitles() {
    return _db
        .watchPublisherTitles()
        .debounceTime(const Duration(milliseconds: 300));
  }

  /// Watch playlists as domain models.
  ///
  /// Ordered by publisher_id ASC, created_at_us ASC (canonical order).
  /// Use [channelIds] for single or multiple channels.
  Stream<List<Playlist>> watchPlaylists({
    PlaylistType? type,
    List<String>? channelIds,
    String? ownerAddress,
    int? limit,
  }) {
    return _db
        .watchPlaylists(
          type: type?.index,
          channelIds: channelIds,
          ownerAddress: ownerAddress,
          limit: limit,
        )
        .debounceTime(const Duration(milliseconds: 300))
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
        .throttleTime(
          const Duration(milliseconds: 300),
          leading: true,
          trailing: true,
        )
        .map(
          (rows) =>
              rows.map(DatabaseConverters.itemDataToDomainPreview).toList(),
        );
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
        .debounceTime(const Duration(milliseconds: 300))
        .map(
          (rows) => rows.map(DatabaseConverters.itemDataToDomain).toList(),
        );
  }

  // ========== Channel Operations ==========

  /// Ingest/update a publisher row.
  Future<void> ingestPublisher({
    required int id,
    required String name,
  }) async {
    final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
    final companion = PublishersCompanion.insert(
      id: Value(id),
      title: name,
      createdAtUs: nowUs,
      updatedAtUs: nowUs,
    );
    await _db.upsertPublisher(companion);
  }

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

  /// Watch a single channel by ID as domain model. Emits null if the channel is
  /// deleted or not found.
  Stream<Channel?> watchChannelById(String id) {
    return _db
        .watchChannelById(id)
        .debounceTime(const Duration(milliseconds: 300))
        .map(
          (data) => data != null
              ? DatabaseConverters.channelDataToDomain(data)
              : null,
        );
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

  /// Watch a single playlist by ID.
  Stream<Playlist?> watchPlaylistById(String id) {
    return _db
        .watchPlaylistById(id)
        .map(
          (data) => data != null
              ? DatabaseConverters.playlistDataToDomain(data)
              : null,
        );
  }

  /// Get all playlists.
  ///
  /// When [type] is provided, results are filtered by playlist type.
  Future<List<Playlist>> getAllPlaylists({PlaylistType? type}) async {
    try {
      final data = await _db.getAllPlaylists(type: type);
      final playlists = data
          .map(DatabaseConverters.playlistDataToDomain)
          .toList();
      _log.info(
        'Retrieved ${playlists.length} playlists from database'
        '${type != null ? ' (type: ${type.name})' : ''}',
      );
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
      if (_isDatabaseUnavailableError(e)) {
        _log.warning(
          'Address playlists query skipped (database closed during seed replace '
          'or reset): $e',
        );
        rethrow;
      }
      _log.severe('Failed to get address playlists', e, stack);
      rethrow;
    }
  }

  // ========== Playlist Entry Operations ==========

  /// Add or update a playlist entry (e.g. for Favorite/History).
  /// Uses [sortKeyUs] for provenance ordering (higher = more recent).
  Future<void> addPlaylistEntry({
    required String playlistId,
    required String itemId,
    required int sortKeyUs,
  }) async {
    try {
      final entry = DatabaseConverters.createPlaylistEntry(
        playlistId: playlistId,
        itemId: itemId,
        sortKeyUs: sortKeyUs,
      );
      await _db.upsertPlaylistEntry(entry);
      await _db.updatePlaylistItemCount(playlistId);
    } catch (e, stack) {
      _log.severe(
        'Failed to add playlist entry $playlistId/$itemId',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Remove a playlist entry.
  Future<void> removePlaylistEntry({
    required String playlistId,
    required String itemId,
  }) async {
    try {
      await _db.deletePlaylistEntry(
        playlistId: playlistId,
        itemId: itemId,
      );
      await _db.updatePlaylistItemCount(playlistId);
    } catch (e, stack) {
      _log.severe(
        'Failed to remove playlist entry $playlistId/$itemId',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Check whether a work is in a playlist (e.g. Favorite).
  Future<bool> hasPlaylistEntry({
    required String playlistId,
    required String itemId,
  }) async {
    return _db.hasPlaylistEntry(
      playlistId: playlistId,
      itemId: itemId,
    );
  }

  /// Watch whether a work is in a playlist (e.g. Favorite).
  Stream<bool> watchHasPlaylistEntry({
    required String playlistId,
    required String itemId,
  }) {
    return _db
        .watchHasPlaylistEntry(playlistId: playlistId, itemId: itemId)
        .debounceTime(const Duration(milliseconds: 200));
  }

  /// Get Favorite playlists snapshot for rebuild-metadata restore.
  ///
  /// Returns one [FavoritePlaylistSnapshot] per favorite playlist
  /// (playlist + items; entries are recreated on restore). Items order
  /// comes from `getPlaylistItemsByProvenance`; that same order is
  /// preserved on `restoreFavoritePlaylistsSnapshot` (no sortKeyUs stored).
  Future<List<FavoritePlaylistSnapshot>> getFavoritePlaylistsSnapshot() async {
    final playlistsData = await _db.getAllPlaylists(
      type: PlaylistType.favorite,
    );
    final playlists = playlistsData
        .map(DatabaseConverters.playlistDataToDomain)
        .toList();

    final snapshots = <FavoritePlaylistSnapshot>[];
    for (final playlist in playlists) {
      final items = await _db.getPlaylistItemsByProvenance(playlist.id);
      snapshots.add(
        FavoritePlaylistSnapshot(
          playlist: playlist,
          items: items,
        ),
      );
    }
    return snapshots;
  }

  /// Restore Favorite playlists from snapshot after rebuild-metadata.
  ///
  /// Uses the exact order of snapshot items as the restore order. Snapshots
  /// are created by `getFavoritePlaylistsSnapshot` via
  /// `getPlaylistItemsByProvenance`, so capture order = restore order.
  /// No sortKeyUs in snapshot; we assign
  /// sortKeys from list index so provenance ordering (DESC) matches.
  Future<void> restoreFavoritePlaylistsSnapshot(
    List<FavoritePlaylistSnapshot> snapshots,
  ) async {
    if (snapshots.isEmpty) return;
    try {
      for (final snapshot in snapshots) {
        final playlist = snapshot.playlist;
        final items = snapshot.items;

        if (items.isNotEmpty) {
          final companions = items.map((i) => i.toCompanion(true)).toList();
          await _db.upsertItems(companions, force: false);
        }

        final companion = DatabaseConverters.playlistToCompanion(playlist);
        await _db.upsertPlaylist(companion);

        if (items.isNotEmpty) {
          final nowUs = DateTime.now().microsecondsSinceEpoch;
          // items = newest-first from getPlaylistItemsByProvenance. Reverse to
          // oldest-first, then assign sortKeyUs = nowUs + index so DESC sort
          // restores original order (newest first).
          final oldestFirst = items.reversed.toList();
          final entryCompanions = oldestFirst.asMap().entries.map((e) {
            return DatabaseConverters.createPlaylistEntry(
              playlistId: playlist.id,
              itemId: e.value.id,
              sortKeyUs: nowUs + e.key,
            );
          }).toList();
          await _db.upsertPlaylistEntries(entryCompanions);
        }

        await _db.updatePlaylistItemCount(playlist.id);
      }
      _log.info(
        'Restored ${snapshots.length} Favorite playlist(s) from snapshot',
      );
    } catch (e, stack) {
      _log.severe('Failed to restore Favorite playlists', e, stack);
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
  ///
  /// When [shouldForce] is true (default), existing rows are overwritten.
  /// When [shouldForce] is false, existing rows are preserved.
  Future<void> upsertPlaylistItemsEnriched(
    List<PlaylistItem> items, {
    bool shouldForce = true,
  }) async {
    if (items.isEmpty) return;

    try {
      await _db.transaction(() async {
        final companions = items
            .map(DatabaseConverters.playlistItemToCompanion)
            .toList();
        await _db.upsertItems(companions, force: shouldForce);
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

  /// Get playlist items by a list of IDs.
  ///
  /// Returns domain [PlaylistItem]s for each ID found in the database.
  /// Order of the result follows the order of [ids]; IDs not found are skipped.
  Future<List<PlaylistItem>> getPlaylistItemsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final data = await _db.getItemsByIds(ids);
      final byId = {
        for (final d in data) d.id: DatabaseConverters.itemDataToDomain(d),
      };
      return [
        for (final id in ids)
          if (byId.containsKey(id)) byId[id]!,
      ];
    } catch (e, stack) {
      if (_isDatabaseUnavailableError(e)) {
        _log.warning(
          'getPlaylistItemsByIds skipped while database is closed '
          '(seed replace / reset): $e',
        );
        return [];
      }
      _log.severe('Failed to get playlist items by ids', e, stack);
      rethrow;
    }
  }

  /// Watch a single playlist item by ID; emits when the row changes or is removed.
  Stream<PlaylistItem?> watchPlaylistItemById(String id) {
    return _db
        .watchItemById(id)
        .debounceTime(const Duration(milliseconds: 300))
        .map((data) {
          if (data == null) return null;
          try {
            return DatabaseConverters.itemDataToDomain(data);
          } catch (e, stack) {
            _log.severe('Failed to convert playlist item $id', e, stack);
            rethrow;
          }
        })
        .handleError((Object e, StackTrace stack) {
          _log.severe('Watch playlist item $id error', e, stack);
        });
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

  /// Search channels using title-first FTS with metadata fallback.
  Future<List<Channel>> searchChannels(
    String query, {
    int limit = 20,
  }) async {
    try {
      final data = await _db.searchChannelsByTitleFts(query, limit: limit);
      return data.map(DatabaseConverters.channelDataToDomain).toList();
    } catch (e, stack) {
      _log.severe('Failed to search channels', e, stack);
      rethrow;
    }
  }

  /// Search playlists using title-first FTS with metadata fallback.
  Future<List<Playlist>> searchPlaylists(
    String query, {
    int limit = 20,
  }) async {
    try {
      final data = await _db.searchPlaylistsByTitleFts(query, limit: limit);
      return data.map(DatabaseConverters.playlistDataToDomainPreview).toList();
    } catch (e, stack) {
      _log.severe('Failed to search playlists', e, stack);
      rethrow;
    }
  }

  /// Search works/items using title and artist FTS.
  Future<List<PlaylistItem>> searchItems(
    String query, {
    int limit = 20,
  }) async {
    try {
      final data = await _db.searchItemsByTitleFts(query, limit: limit);
      return data.map(DatabaseConverters.itemDataToDomainPreview).toList();
    } catch (e, stack) {
      _log.severe('Failed to search items', e, stack);
      rethrow;
    }
  }

  /// Search item IDs that match artist names only.
  Future<Set<String>> searchArtistMatchedItemIds(
    String query, {
    Set<String>? candidateIds,
    int limit = 40,
  }) async {
    try {
      final ids = await _db.searchItemIdsByArtistFts(
        query,
        candidateIds: candidateIds?.toList(growable: false),
        limit: limit,
      );
      return ids.toSet();
    } catch (e, stack) {
      _log.severe('Failed to search artist-matched item ids', e, stack);
      rethrow;
    }
  }

  /// Backward-compatible wrapper for [searchChannels].
  @Deprecated('Use searchChannels instead')
  Future<List<Channel>> searchChannelsByTitle(
    String query, {
    int limit = 20,
  }) {
    return searchChannels(query, limit: limit);
  }

  /// Backward-compatible wrapper for [searchPlaylists].
  @Deprecated('Use searchPlaylists instead')
  Future<List<Playlist>> searchPlaylistsByTitle(
    String query, {
    int limit = 20,
  }) {
    return searchPlaylists(query, limit: limit);
  }

  /// Backward-compatible wrapper for [searchItems].
  @Deprecated('Use searchItems instead')
  Future<List<PlaylistItem>> searchItemsByTitle(
    String query, {
    int limit = 20,
  }) {
    return searchItems(query, limit: limit);
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

  /// Get ordered item IDs with optional [limit] and [offset] for diff windows.
  Future<List<String>> getItemIds({int? limit, int? offset}) async {
    try {
      return _db.getItemIds(limit: limit, offset: offset);
    } catch (e, stack) {
      _log.severe('Failed to get item ids', e, stack);
      rethrow;
    }
  }

  /// Debounce duration for items revision signal (reduces emissions on rapid DB changes).
  static const Duration watchAllItemsDebounce = Duration(milliseconds: 300);

  /// Watch only a lightweight "items changed" signal.
  ///
  /// Emits item count values and re-emits when the items table changes.
  /// Use this when only invalidation notifications are needed (avoids materializing all rows).
  Stream<int> watchItemsRevisionSignal() {
    return _db.watchItemsRevisionSignal().debounceTime(watchAllItemsDebounce);
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

  /// Delete playlist by ID.
  ///
  /// This deletes the playlist record and all its entries.
  /// Items are not deleted (they may be referenced by other playlists).
  /// Set [skipEntries] to true when entries were already deleted (e.g. by
  /// [deleteItemsOfAddresses]).
  Future<void> deletePlaylist(
    String playlistId, {
    bool skipEntries = false,
  }) async {
    try {
      if (!skipEntries) {
        await _db.deletePlaylistEntries(playlistId);
      }
      await _db.deletePlaylist(playlistId);
      _log.info('Deleted playlist: $playlistId');
    } catch (e, stack) {
      _log.severe('Failed to delete playlist $playlistId', e, stack);
      rethrow;
    }
  }

  /// Delete playlist entries and items for address-based playlists.
  ///
  /// Matches playlists by [addresses] (case-insensitive) and removes all
  /// playlist entries and items belonging to those playlists in one SQL batch.
  Future<void> deleteItemsOfAddresses(List<String> addresses) async {
    if (addresses.isEmpty) return;

    final normalized = addresses
        .map((a) => a.toNormalizedAddress())
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();
    if (normalized.isEmpty) return;

    try {
      await _db.deleteItemsAndEntriesOfAddresses(normalized);
      _log.info('Deleted items and entries for address(es)');
    } catch (e, stack) {
      _log.severe('Failed to delete items of addresses', e, stack);
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
      final normalizedAddress = address.toNormalizedAddress();

      final playlists = await getAddressPlaylists();
      Playlist? addressPlaylist;
      for (final playlist in playlists) {
        if (playlist.ownerAddress?.toNormalizedAddress() == normalizedAddress) {
          addressPlaylist = playlist;
          break;
        }
      }
      if (addressPlaylist == null) {
        _log.info(
          'Address playlist not found for $address while deleting tokens; '
          'skipping stale change batch.',
        );
        return;
      }
      final addressPlaylistId = addressPlaylist.id;

      await _runWithDatabaseLockedRetry<void>(() async {
        for (final cid in cids) {
          if (cid.isEmpty) continue;
          await _db.deletePlaylistEntry(
            playlistId: addressPlaylistId,
            itemId: cid,
          );
        }
        await _db.updatePlaylistItemCount(addressPlaylistId);
        await _db.checkpoint();
      });

      _log.info(
        'Deleted ${cids.length} tokens from address playlist for $address',
      );
    } catch (e, stack) {
      if (_isDatabaseLockedError(e)) {
        _log.warning(
          'Database remained locked deleting tokens for $address; '
          'dropping batch during reset/teardown.',
          e,
          stack,
        );
        return;
      }
      _log.severe('Failed to delete tokens for address $address', e, stack);
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
      final normalizedAddress = address.toNormalizedAddress();

      // Find the address playlist
      final playlists = await getAddressPlaylists();
      Playlist? addressPlaylist;
      for (final playlist in playlists) {
        if (playlist.ownerAddress?.toNormalizedAddress() == normalizedAddress) {
          addressPlaylist = playlist;
          break;
        }
      }
      if (addressPlaylist == null) {
        _log.info(
          'Address playlist not found for $address while ingesting tokens; '
          'skipping stale change batch.',
        );
        return;
      }
      final addressPlaylistId = addressPlaylist.id;

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

      // Create playlist entries (sort key from item.sortKeyUs)
      final entries = items.map((item) {
        return DatabaseConverters.createPlaylistEntry(
          playlistId: addressPlaylistId,
          itemId: item.id,
          sortKeyUs: item.sortKeyUs ?? 0,
        );
      }).toList();

      final itemCompanions = items
          .map(DatabaseConverters.playlistItemToCompanion)
          .toList();

      await _runWithDatabaseLockedRetry<void>(() async {
        await _db.transaction(() async {
          await _db.upsertItems(itemCompanions);
          await _db.upsertPlaylistEntries(entries);
          await _db.updatePlaylistItemCount(addressPlaylistId);
        });
        await _db.checkpoint();
      });

      _log.info(
        'Ingested ${items.length} tokens for address $address',
      );
    } catch (e, stack) {
      if (_isOperationCancelled(e)) {
        _log.info(
          'Token ingest cancelled for address $address (non-fatal): $e',
        );
        return;
      }
      if (_isDatabaseLockedError(e)) {
        _log.warning(
          'Database remained locked ingesting tokens for $address; '
          'dropping batch during reset/teardown.',
          e,
          stack,
        );
        return;
      }
      if (_isDatabaseUnavailableError(e)) {
        _log.warning(
          'Database unavailable during token ingest for $address '
          '(Forget I Exist / seed replace); dropping batch.',
          e,
          stack,
        );
        return;
      }
      _log.severe('Failed to ingest tokens for address $address', e, stack);
      rethrow;
    }
  }

  /// Ingest DP1 playlist (wire model) into the database.
  ///
  /// Items are the main source of truth. When [tokens] is provided, each item
  /// is matched by CID and enriched with `thumbnailUrl` and DP1 `artists` from
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

  /// Clear all data from the database (for testing/reset).
  ///
  /// Uses a single batch so all deletes run in one transaction and the DB lock
  /// is held briefly. Using separate transaction + multiple delete.go() can
  /// trigger "database has been locked" when watch streams (channels/playlists)
  /// try to read during the transaction.
  Future<void> clearAll() async {
    try {
      await _db.batch((batch) {
        // Child tables first (playlist_entries references playlists and items).
        batch
          ..deleteAll(_db.playlistEntries)
          ..deleteAll(_db.items)
          ..deleteAll(_db.playlists)
          ..deleteAll(_db.channels)
          ..deleteAll(_db.publishers);
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

  /// Ingest one DP1 channel and all its playlists/items in a single transaction.
  ///
  /// This is optimized for curated channel bootstrap where one channel URL
  /// should be persisted atomically to reduce lock churn and watcher invalidation.
  Future<void> ingestDP1ChannelWithPlaylistsBare({
    required String baseUrl,
    required DP1Channel channel,
    required List<DP1Playlist> playlists,
    int? publisherId,
  }) async {
    try {
      // Avoid computeWithDatabase() here: opening a short-lived extra
      // connection can contend with worker writes and trigger SQLITE_BUSY.
      // NativeDatabase.createInBackground already runs writes off the UI
      // isolate, so execute on the current Drift executor and retry
      // transient lock errors.
      await _runWithDatabaseLockedRetry<void>(() {
        return _ingestDP1ChannelWithPlaylistsBareOnDatabase(
          db: _db,
          baseUrl: baseUrl,
          channel: channel,
          playlists: playlists,
          publisherId: publisherId,
        );
      });

      _log.info(
        'Ingested channel ${channel.id} with ${playlists.length} playlists '
        'in one transaction',
      );
    } catch (e, stack) {
      _log.severe(
        'Failed to ingest channel ${channel.id} with playlists in one transaction',
        e,
        stack,
      );
      rethrow;
    }
  }

  static Future<void> _ingestDP1ChannelWithPlaylistsBareOnDatabase({
    required AppDatabase db,
    required String baseUrl,
    required DP1Channel channel,
    required List<DP1Playlist> playlists,
    int? publisherId,
  }) async {
    final domainChannel = Channel(
      id: channel.id,
      name: channel.title,
      type: ChannelType.dp1,
      description: channel.summary,
      baseUrl: baseUrl,
      slug: channel.slug,
      publisherId: publisherId,
      curator: channel.curator,
      coverImageUrl: channel.coverImage,
      createdAt: channel.created,
      updatedAt: channel.created,
    );

    final channelCompanion = DatabaseConverters.channelToCompanion(
      domainChannel,
    );
    final playlistCompanions = <PlaylistsCompanion>[];
    final itemCompanions = <ItemsCompanion>[];
    final entryCompanions = <PlaylistEntriesCompanion>[];
    final playlistIds = <String>[];

    for (final playlist in playlists) {
      final domainPlaylist = DatabaseConverters.dp1PlaylistToDomain(
        playlist,
        baseUrl: baseUrl,
        channelId: channel.id,
      );
      playlistCompanions.add(
        DatabaseConverters.playlistToCompanion(domainPlaylist),
      );
      playlistIds.add(domainPlaylist.id);

      for (var i = 0; i < playlist.items.length; i++) {
        final bareItem = DatabaseConverters.dp1PlaylistItemToPlaylistItem(
          playlist.items[i],
        );
        itemCompanions.add(
          DatabaseConverters.playlistItemToCompanion(bareItem),
        );
        entryCompanions.add(
          DatabaseConverters.createPlaylistEntry(
            playlistId: domainPlaylist.id,
            itemId: bareItem.id,
            position: i,
            sortKeyUs: 0,
          ),
        );
      }
    }

    await db.transaction(() async {
      await db.batch((batch) {
        batch.insertAllOnConflictUpdate(db.channels, [channelCompanion]);
        if (playlistCompanions.isNotEmpty) {
          batch.insertAllOnConflictUpdate(db.playlists, playlistCompanions);
        }
        if (itemCompanions.isNotEmpty) {
          batch.insertAllOnConflictUpdate(db.items, itemCompanions);
        }
        if (entryCompanions.isNotEmpty) {
          batch.insertAllOnConflictUpdate(db.playlistEntries, entryCompanions);
        }
      });

      for (final playlistId in playlistIds) {
        await db.updatePlaylistItemCount(playlistId);
      }
    });
  }

  Future<T> _runWithDatabaseLockedRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await action();
      } on Object catch (e, stack) {
        lastError = e;
        lastStack = stack;
        final isLocked = e.toString().contains('database is locked');
        if (!isLocked || attempt == maxAttempts) {
          rethrow;
        }
        final delayMs = 100 * attempt;
        _log.warning(
          'Database locked during write (attempt $attempt/$maxAttempts); '
          'retrying in ${delayMs}ms',
          e,
          stack,
        );
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }

    if (lastError != null && lastStack != null) {
      Error.throwWithStackTrace(lastError, lastStack);
    }
    throw StateError('Unreachable database retry state');
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

  // ===========================================================================
  // Enrichment queries (SQLite as single source of truth)
  // ===========================================================================

  /// Load high-priority bare items from database.
  ///
  /// Loads high-priority bare items for enrichment.
  ///
  /// Selects the first [maxPerPlaylist] items from every playlist that has
  /// unenriched items, ordering results newest-playlist-first (matching UI
  /// display order), then by item position within each playlist. The result
  /// is capped at [maxItems] total rows.
  ///
  /// Unlike a fixed-playlist-count approach, this fills the target batch size
  /// across as many playlists as needed so that small playlists do not leave
  /// the batch under-populated.
  Future<List<(String, String?, String, int)>> loadHighPriorityBareItems({
    required int maxPerPlaylist,
    required int maxItems,
  }) async {
    try {
      final query = _db.customSelect(
        '''
        WITH ranked AS (
          -- Top N items per playlist (by position), across all playlists.
          SELECT
            pe.playlist_id,
            pe.item_id,
            i.provenance_json,
            pe.position,
            p.created_at_us AS playlist_created_at,
            ROW_NUMBER() OVER (
              PARTITION BY pe.playlist_id
              ORDER BY
                COALESCE(pe.position, 2147483647) ASC,
                pe.item_id ASC
            ) AS item_rank
          FROM playlist_entries pe
          JOIN playlists p ON pe.playlist_id = p.id
          JOIN items i ON pe.item_id = i.id
          WHERE i.thumbnail_uri IS NULL
            AND i.list_artist_json IS NULL
            AND i.enrichment_status != ?3
        )
        SELECT playlist_id, item_id, provenance_json, position
        FROM ranked
        WHERE item_rank <= ?1
        ORDER BY playlist_created_at DESC, playlist_id ASC, item_rank ASC
        LIMIT ?2
        ''',
        variables: [
          Variable.withInt(maxPerPlaylist),
          Variable.withInt(maxItems),
          Variable.withInt(enrichmentStatusFailed),
        ],
      );

      final rows = await query.get();
      final result = <(String, String?, String, int)>[];

      for (final row in rows) {
        final playlistId = row.read<String>('playlist_id');
        final itemId = row.read<String>('item_id');
        final provenanceJson = row.readNullable<String>('provenance_json');
        final position = row.readNullable<int>('position') ?? -1;
        result.add((itemId, provenanceJson, playlistId, position));
      }

      _log.fine('Loaded ${result.length} high-priority bare items');
      return result;
    } catch (e, stack) {
      if (_isOperationCancelled(e)) {
        _log.fine('High-priority bare-items query cancelled');
        return const <(String, String?, String, int)>[];
      }
      _log.severe('Failed to load high-priority bare items', e, stack);
      rethrow;
    }
  }

  /// Loads low-priority bare items for enrichment.
  ///
  /// Returns bare items beyond the first [maxPerPlaylist] items per playlist,
  /// ordered by newest-playlist-first (matching UI display order) and then by
  /// item position within each playlist. Up to [maxTotal] items are returned.
  Future<List<(String, String?, String, int)>> loadLowPriorityBareItems({
    required int maxPerPlaylist,
    required int maxTotal,
  }) async {
    try {
      final query = _db.customSelect(
        '''
        WITH ranked AS (
          SELECT
            pe.playlist_id,
            pe.item_id,
            i.provenance_json,
            pe.position,
            p.created_at_us AS playlist_created_at,
            ROW_NUMBER() OVER (
              PARTITION BY pe.playlist_id
              ORDER BY
                COALESCE(pe.position, 2147483647) ASC,
                pe.item_id ASC
            ) AS item_rank
          FROM playlist_entries pe
          JOIN playlists p ON pe.playlist_id = p.id
          JOIN items i ON pe.item_id = i.id
          WHERE i.thumbnail_uri IS NULL
            AND i.list_artist_json IS NULL
            AND i.enrichment_status != ?3
        )
        SELECT playlist_id, item_id, provenance_json, position
        FROM ranked
        WHERE item_rank > ?1
        ORDER BY playlist_created_at DESC, playlist_id ASC, item_rank ASC
        LIMIT ?2
        ''',
        variables: [
          Variable.withInt(maxPerPlaylist),
          Variable.withInt(maxTotal),
          Variable.withInt(enrichmentStatusFailed),
        ],
      );

      final rows = await query.get();
      final result = <(String, String?, String, int)>[];

      for (final row in rows) {
        final playlistId = row.read<String>('playlist_id');
        final itemId = row.read<String>('item_id');
        final provenanceJson = row.readNullable<String>('provenance_json');
        final position = row.readNullable<int>('position') ?? -1;
        result.add((itemId, provenanceJson, playlistId, position));
      }

      _log.fine('Loaded ${result.length} low-priority bare items');
      return result;
    } catch (e, stack) {
      if (_isOperationCancelled(e)) {
        _log.fine('Low-priority bare-items query cancelled');
        return const <(String, String?, String, int)>[];
      }
      _log.severe('Failed to load low-priority bare items', e, stack);
      rethrow;
    }
  }

  /// Enrich a single playlist item with token data.
  ///
  /// Updates the item in database with provenance, source, thumbnail, artists,
  /// and other DP-1 fields from the token.
  Future<void> enrichPlaylistItemWithToken({
    required String itemId,
    required AssetToken token,
  }) async {
    try {
      final enrichedItem = TokenTransformer.assetTokenToPlaylistItem(
        token: token,
      );
      final companion = _buildEnrichmentCompanion(
        itemId: itemId,
        enrichedItem: enrichedItem,
        nowUs: BigInt.from(DateTime.now().microsecondsSinceEpoch),
      );
      await _db.upsertItem(companion);
    } catch (e, stack) {
      _log.severe('Failed to enrich item $itemId', e, stack);
      rethrow;
    }
  }

  /// Enrich multiple playlist items in a single database transaction.
  Future<void> enrichPlaylistItemsWithTokensBatch({
    required List<(String, AssetToken)> enrichments,
  }) async {
    if (enrichments.isEmpty) return;

    try {
      final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
      // Hot path: avoid computeWithDatabase() here because it spawns a short-
      // lived isolate per batch and adds IPC overhead. SQL still runs on
      // Drift's background writer isolate via NativeDatabase.createInBackground.
      await _enrichPlaylistItemsWithTokensBatchOnDatabase(
        db: _db,
        enrichments: enrichments,
        nowUs: nowUs,
      );
    } catch (e, stack) {
      _log.severe(
        'Failed to enrich ${enrichments.length} items in batch',
        e,
        stack,
      );
      rethrow;
    }
  }

  /// Marks items as failed to enrich so query workers skip retrying them.
  Future<void> markPlaylistItemsEnrichmentFailed(List<String> itemIds) async {
    if (itemIds.isEmpty) return;

    try {
      final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
      await _db.transaction(() async {
        for (final itemId in itemIds) {
          await (_db.update(
            _db.items,
          )..where((t) => t.id.equals(itemId))).write(
            ItemsCompanion(
              enrichmentStatus: const Value(enrichmentStatusFailed),
              updatedAtUs: Value(nowUs),
            ),
          );
        }
      });
      _log.info('Marked ${itemIds.length} items as enrichment-failed');
    } catch (e, stack) {
      _log.severe('Failed to mark enrichment-failed items', e, stack);
      rethrow;
    }
  }

  /// Build [ItemsCompanion] for enrichment from [PlaylistItem].
  ///
  /// Persists provenance, sourceUri, refUri, durationSec, license, repro,
  /// display, thumbnail, and artists to preserve DP-1 compatibility.
  static ItemsCompanion _buildEnrichmentCompanion({
    required String itemId,
    required PlaylistItem enrichedItem,
    required BigInt nowUs,
  }) {
    return ItemsCompanion(
      id: Value(itemId),
      kind: const Value(1), // indexer token
      title: Value(enrichedItem.title),
      thumbnailUri: Value(enrichedItem.thumbnailUrl),
      provenanceJson: enrichedItem.provenance != null
          ? Value(jsonEncode(enrichedItem.provenance!.toJson()))
          : const Value.absent(),
      sourceUri: enrichedItem.source != null
          ? Value(enrichedItem.source)
          : const Value.absent(),
      refUri: enrichedItem.ref != null
          ? Value(enrichedItem.ref)
          : const Value.absent(),
      durationSec: enrichedItem.duration > 0
          ? Value(enrichedItem.duration)
          : const Value.absent(),
      license: enrichedItem.license != null
          ? Value(enrichedItem.license!.value)
          : const Value.absent(),
      reproJson: enrichedItem.repro != null
          ? Value(jsonEncode(enrichedItem.repro!.toJson()))
          : const Value.absent(),
      displayJson: enrichedItem.display != null
          ? Value(jsonEncode(enrichedItem.display!.toJson()))
          : const Value.absent(),
      listArtistJson:
          enrichedItem.artists != null && enrichedItem.artists!.isNotEmpty
          ? Value(
              jsonEncode(
                enrichedItem.artists!.map((a) => a.toJson()).toList(),
              ),
            )
          : const Value(null),
      enrichmentStatus: const Value(enrichmentStatusEnriched),
      updatedAtUs: Value(nowUs),
    );
  }

  static Future<void> _enrichPlaylistItemsWithTokensBatchOnDatabase({
    required AppDatabase db,
    required List<(String, AssetToken)> enrichments,
    required BigInt nowUs,
  }) async {
    final companions = enrichments
        .map((enrichment) {
          final itemId = enrichment.$1;
          final token = enrichment.$2;
          final enrichedItem = TokenTransformer.assetTokenToPlaylistItem(
            token: token,
          );
          return _buildEnrichmentCompanion(
            itemId: itemId,
            enrichedItem: enrichedItem,
            nowUs: nowUs,
          );
        })
        .toList(growable: false);

    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(db.items, companions);
    });
  }

  /// Build token CIDs from raw bare-item rows on a worker isolate.
  ///
  /// This offloads JSON decoding of `provenance_json` from the UI isolate.
  Future<List<(String, String, String, int)>> extractTokenCidsFromBareRows({
    required List<(String, String?, String, int)> rows,
  }) async {
    if (rows.isEmpty) return const <(String, String, String, int)>[];
    // For typical enrichment batches (<= 50), isolate spawn/IPC overhead can
    // dominate. Offload only when input is large enough to benefit.
    if (rows.length < 200) {
      return _extractTokenCidRows(rows);
    }
    return Isolate.run(() => _extractTokenCidRows(rows));
  }

  /// Build token CID from provenance json.
  String? buildTokenCidFromProvenanceJson(String? provenanceJson) {
    return _buildTokenCidFromProvenanceJson(provenanceJson);
  }
}

bool _isDatabaseLockedError(Object error) {
  return error.toString().contains('database is locked');
}

/// Returns true when the DB is unavailable during reset (e.g. Forget I Exist).
bool _isDatabaseUnavailableError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('database has been closed') ||
      msg.contains('database is closed') ||
      msg.contains('channel was closed') ||
      msg.contains('connection was closed') ||
      msg.contains('couldnotrollbackexception') ||
      msg.contains('unable to open database file') ||
      msg.contains('no such table') ||
      msg.contains('bad state: this database is no longer open') ||
      msg.contains('bad state: no element');
}

bool _isOperationCancelled(Object error) {
  return error.runtimeType.toString() == 'CancellationException' ||
      error.toString().contains('Operation was cancelled');
}

List<(String, String, String, int)> _extractTokenCidRows(
  List<(String, String?, String, int)> rows,
) {
  final withCid = <(String, String, String, int)>[];

  for (final row in rows) {
    final cid = _buildTokenCidFromProvenanceJson(row.$2);
    if (cid == null || cid.isEmpty) {
      continue;
    }
    withCid.add((row.$1, cid, row.$3, row.$4));
  }

  return withCid;
}

String? _buildTokenCidFromProvenanceJson(String? provenanceJson) {
  if (provenanceJson == null || provenanceJson.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(provenanceJson);
    if (decoded is! Map) {
      return null;
    }

    final decodedMap = Map<String, dynamic>.from(decoded);
    final contractRaw = decodedMap['contract'];
    if (contractRaw is! Map) {
      return null;
    }

    final contract = Map<String, dynamic>.from(contractRaw);
    final chainRaw = contract['chain']?.toString().toLowerCase();
    if (chainRaw == null || chainRaw.isEmpty) {
      return null;
    }

    final prefix = _cidPrefixForChain(chainRaw);
    if (prefix == null || prefix.isEmpty) {
      return null;
    }

    final standard = contract['standard']?.toString().toLowerCase();
    if (standard == null || standard.isEmpty || standard == 'other') {
      return null;
    }

    final address = contract['address']?.toString();
    if (address == null || address.isEmpty) {
      return null;
    }
    final normalizedAddress = _normalizeCidAddress(prefix, address);

    final tokenId = contract['tokenId']?.toString();
    if (tokenId == null || tokenId.isEmpty) {
      return null;
    }

    return '$prefix:$standard:$normalizedAddress:$tokenId';
  } on Object {
    return null;
  }
}

String? _cidPrefixForChain(String chain) {
  if (chain.startsWith('eip155:')) {
    return chain;
  }
  if (chain.startsWith('tezos:')) {
    return chain;
  }

  switch (chain) {
    case 'evm':
    case 'ethereum':
    case 'eth':
      return 'eip155:1';
    case 'tezos':
    case 'tez':
      return 'tezos:mainnet';
    default:
      return null;
  }
}

String _normalizeCidAddress(String chainPrefix, String address) {
  if (!chainPrefix.startsWith('eip155:')) {
    return address;
  }

  try {
    final parsed = wallet.EthereumAddress.fromHex(
      address,
      enforceEip55: true,
    );
    return parsed.eip55With0x;
  } on Object {
    // Preserve the original address when normalization fails so a valid CID
    // is still attempted for non-standard address formats.
    return address;
  }
}
