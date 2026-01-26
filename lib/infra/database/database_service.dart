import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../../domain/models/channel.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/playlist_item.dart';
import 'app_database.dart';
import 'converters.dart';
import 'token_transformer.dart';

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
      final companions = channels
          .map(DatabaseConverters.channelToCompanion)
          .toList();
      await _db.upsertChannels(companions);
      _log.info('Ingested ${channels.length} channels');
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
      _log.info('Ingested playlist: ${playlist.id}');
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
    required List<Map<String, dynamic>> tokens,
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
      final items = ownedTokens.map((tokenJson) {
        return TokenTransformer.tokenToPlaylistItem(
          tokenJson: tokenJson,
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
    List<Map<String, dynamic>>? enrichmentTokens,
  }) async {
    try {
      // Ingest the playlist
      await ingestPlaylist(playlist);

      if (items.isEmpty) {
        _log.info('No items for DP1 playlist ${playlist.id}');
        return;
      }

      // Create a map of CID -> token for enrichment
      final tokensByCID = <String, Map<String, dynamic>>{};
      if (enrichmentTokens != null) {
        for (final token in enrichmentTokens) {
          final cid = token['id'] as String;
          tokensByCID[cid] = token;
        }
      }

      final playlistItems = <PlaylistItem>[];
      final entries = <PlaylistEntriesCompanion>[];

      for (var i = 0; i < items.length; i++) {
        final item = items[i];
        final itemId = item['id'] as String;

        // Check if we have enrichment data
        final tokenData = tokensByCID[itemId];

        PlaylistItem playlistItem;
        if (tokenData != null) {
          // Use token data for enrichment
          playlistItem = TokenTransformer.tokenToPlaylistItem(
            tokenJson: tokenData,
          );
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
}
