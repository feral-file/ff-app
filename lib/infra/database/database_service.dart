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
import 'package:app/infra/database/token_transformer.dart';

/// Database service providing high-level operations for data ingestion.
/// Handles offline-first storage for DP-1 entities and relationships.
class DatabaseService {
  /// Creates a DatabaseService.
  DatabaseService(this._db) {
    _log = Logger('DatabaseService');
  }

  final AppDatabase _db;
  late final Logger _log;

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
      final companions =
          channels.map(DatabaseConverters.channelToCompanion).toList();
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
      final companions =
          playlists.map(DatabaseConverters.playlistToCompanion).toList();
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
      return data.map(DatabaseConverters.playlistDataToDomain).toList();
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
      final playlists =
          data.map(DatabaseConverters.playlistDataToDomain).toList();
      _log.info('Retrieved ${playlists.length} playlists from database');
      if (playlists.isNotEmpty) {
        _log.info('Sample playlists from database:');
        for (var i = 0; i < playlists.length.clamp(0, 3); i++) {
          final p = playlists[i];
          _log.info(
            '  - ${p.name} | id: ${p.id} | type: ${p.type} | items: ${p.itemCount}',
          );
        }
      }
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
      return data.map(DatabaseConverters.playlistDataToDomain).toList();
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
      final companions =
          items.map(DatabaseConverters.playlistItemToCompanion).toList();
      await _db.upsertItems(companions);
      _log.info('Ingested ${items.length} playlist items');
    } catch (e, stack) {
      _log.severe('Failed to ingest playlist items', e, stack);
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
  Future<List<PlaylistItem>> getPlaylistItems(String playlistId) async {
    try {
      final playlist = await getPlaylistById(playlistId);
      if (playlist == null) {
        _log.warning('Playlist $playlistId not found');
        return [];
      }

      final data = playlist.sortMode == PlaylistSortMode.position
          ? await _db.getPlaylistItemsByPosition(playlistId)
          : await _db.getPlaylistItemsByProvenance(playlistId);

      return data.map(DatabaseConverters.itemDataToDomain).toList();
    } catch (e, stack) {
      _log.severe('Failed to get items for playlist $playlistId', e, stack);
      rethrow;
    }
  }

  /// Get all items from the database.
  Future<List<PlaylistItem>> getAllItems() async {
    try {
      final data = await _db.getAllItems();
      return data.map(DatabaseConverters.itemDataToDomain).toList();
    } catch (e, stack) {
      _log.severe('Failed to get all items', e, stack);
      rethrow;
    }
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

  /// Ingest DP1 playlist with static items.
  /// This fetches tokens from indexer if CIDs are provided.
  Future<void> ingestDP1Playlist({
    required Playlist playlist,
    required List<Map<String, dynamic>> items,
    List<AssetToken>? tokens,
  }) async {
    try {
      // Ingest the playlist
      await ingestPlaylist(playlist);

      if (items.isEmpty) {
        _log.info('No items for DP1 playlist ${playlist.id}');
        return;
      }

      // Create a map of CID -> token for enrichment
      final tokensByCID = <String, AssetToken>{};
      if (tokens != null) {
        for (final token in tokens) {
          tokensByCID[token.cid] = token;
        }
      }

      final playlistItems = <PlaylistItem>[];
      final entries = <PlaylistEntriesCompanion>[];

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final itemId = item['id'] as String; // DP1 item UUID
        final itemCid = item['cid'] as String?; // IPFS CID for token lookup

        // Check if we have enrichment data (lookup by CID, not ID)
        final tokenData = itemCid != null ? tokensByCID[itemCid] : null;

        PlaylistItem playlistItem;
        if (tokenData != null) {
          // Use token data for enrichment
          playlistItem =
              TokenTransformer.assetTokenToPlaylistItem(token: tokenData);
        } else {
          // Create basic playlist item from DP1 item
          // Note: DP1 feed uses 'source' not 'sourceUri', 'ref' not 'refUri'
          final source = item['source'] as String?;
          final ref = item['ref'] as String?;
          final license = item['license'] as String?;
          final durationSec = (item['duration'] as num?)?.toInt();
          final provenanceJson = item['provenance'] as Map<String, dynamic>?;

          playlistItem = PlaylistItem(
            id: itemId,
            kind: PlaylistItemKind.dp1Item,
            title: item['title'] as String? ?? 'Untitled',
            sourceUri: source,
            refUri: ref,
            license: license,
            durationSec: durationSec,
            provenance: provenanceJson,
            updatedAt: DateTime.now(),
          );
        }

        playlistItems.add(playlistItem);

        // Create entry with position
        entries.add(
          DatabaseConverters.createPlaylistEntry(
            playlistId: playlist.id,
            itemId: playlistItem.id,
            position: i,
            sortKeyUs: 0, // Not used for position-based sorting
          ),
        );
      }

      // Batch insert
      await ingestPlaylistItems(playlistItems);
      await _db.upsertPlaylistEntries(entries);
      await _db.updatePlaylistItemCount(playlist.id);

      // Checkpoint WAL to ensure data is written to main database
      await _db.checkpoint();

      _log.info(
        'Ingested DP1 playlist ${playlist.id} with ${playlistItems.length} items',
      );
    } catch (e, stack) {
      _log.severe('Failed to ingest DP1 playlist ${playlist.id}', e, stack);
      rethrow;
    }
  }

  /// Clear all data from the database (for testing/reset).
  Future<void> clearAll() async {
    try {
      await _db.transaction(() async {
        await _db.delete(_db.playlistEntries).go();
        await _db.delete(_db.items).go();
        await _db.delete(_db.playlists).go();
        await _db.delete(_db.channels).go();
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
  /// - Converts DP1 wire models to domain models
  /// - Enriches playlist items using [tokens] when provided
  /// - Persists playlist + items + entries
  Future<void> ingestDP1PlaylistWire({
    required String baseUrl,
    required DP1Playlist playlist,
    List<AssetToken>? tokens,
  }) async {
    final dynamicQueries = playlist.dynamicQueries.isNotEmpty
        ? <String, dynamic>{
            'queries': playlist.dynamicQueries.map((e) => e.toJson()).toList(),
          }
        : null;

    final sortMode = dynamicQueries != null
        ? PlaylistSortMode.provenance
        : PlaylistSortMode.position;

    final signatures =
        playlist.signature.isNotEmpty ? <String>[playlist.signature] : null;

    final playlistModel = Playlist(
      id: playlist.id,
      name: playlist.title,
      type: PlaylistType.dp1,
      playlistSource: PlaylistSource.curated,
      baseUrl: baseUrl,
      dpVersion: playlist.dpVersion,
      slug: playlist.slug,
      signatures: signatures,
      defaults: playlist.defaults,
      dynamicQueries: dynamicQueries,
      sortMode: sortMode,
      createdAt: playlist.created,
      updatedAt: playlist.created,
    );

    final itemMaps = playlist.items.map((DP1PlaylistItem item) {
      final map = item.toJson();
      final cid = item.cid;
      if (cid != null) {
        map['cid'] = cid;
      }
      return map;
    }).toList();

    await ingestDP1Playlist(
      playlist: playlistModel,
      items: itemMaps,
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
