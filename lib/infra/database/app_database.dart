import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'app_database.g.dart';

final _log = Logger('AppDatabase');

/// Main application database using Drift.
/// Implements offline-first storage for DP-1 entities and relationships.
@DriftDatabase(tables: [Channels, Playlists, Items, PlaylistEntries])
class AppDatabase extends _$AppDatabase {
  /// Creates an AppDatabase instance.
  AppDatabase() : super(_openConnection());

  /// Creates an AppDatabase instance with a custom executor (for testing).
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createIndexes();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations will be handled here
      },
    );
  }

  /// Creates performance indexes.
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_channels_type_order '
      'ON channels(type, sort_order)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_playlists_channel '
      'ON playlists(channel_id, type)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_playlists_owner '
      'ON playlists(type, owner_address)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_items_kind_updated '
      'ON items(kind, updated_at_us)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_sort '
      'ON playlist_entries(playlist_id, sort_key_us DESC, item_id DESC)',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_position '
      'ON playlist_entries(playlist_id, position ASC, item_id ASC)',
    );
  }

  // Channel queries
  /// Get all channels ordered by sort order.
  Future<List<ChannelData>> getAllChannels() async {
    return (select(channels)..orderBy([
          (t) => OrderingTerm(
            expression: t.sortOrder,
            mode: OrderingMode.asc,
            nulls: NullsOrder.last,
          ),
        ]))
        .get();
  }

  /// Get channel by ID.
  Future<ChannelData?> getChannelById(String id) async {
    return (select(channels)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Upsert a channel.
  Future<void> upsertChannel(ChannelsCompanion channel) async {
    await into(channels).insertOnConflictUpdate(channel);
  }

  /// Upsert multiple channels in a batch.
  Future<void> upsertChannels(List<ChannelsCompanion> channelList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(channels, channelList);
    });
  }

  // Playlist queries
  /// Get all playlists for a channel.
  Future<List<PlaylistData>> getPlaylistsByChannel(String channelId) async {
    return (select(
      playlists,
    )..where((t) => t.channelId.equals(channelId))).get();
  }

  /// Get playlist by ID.
  Future<PlaylistData?> getPlaylistById(String id) async {
    return (select(playlists)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get all playlists.
  Future<List<PlaylistData>> getAllPlaylists() async {
    return select(playlists).get();
  }

  /// Get address-based playlists.
  Future<List<PlaylistData>> getAddressPlaylists() async {
    return (select(playlists)..where((t) => t.type.equals(1))).get();
  }

  /// Upsert a playlist.
  Future<void> upsertPlaylist(PlaylistsCompanion playlist) async {
    await into(playlists).insertOnConflictUpdate(playlist);
  }

  /// Upsert multiple playlists in a batch.
  Future<void> upsertPlaylists(List<PlaylistsCompanion> playlistList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(playlists, playlistList);
    });
  }

  /// Update playlist item count.
  Future<void> updatePlaylistItemCount(String playlistId) async {
    final count =
        await (selectOnly(playlistEntries)
              ..addColumns([playlistEntries.itemId.count()])
              ..where(playlistEntries.playlistId.equals(playlistId)))
            .getSingle()
            .then((row) => row.read(playlistEntries.itemId.count()) ?? 0);

    await (update(playlists)..where((t) => t.id.equals(playlistId))).write(
      PlaylistsCompanion(itemCount: Value(count)),
    );
  }

  // Item queries
  /// Get item by ID.
  Future<ItemData?> getItemById(String id) async {
    return (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get items by IDs.
  Future<List<ItemData>> getItemsByIds(List<String> ids) async {
    return (select(items)..where((t) => t.id.isIn(ids))).get();
  }

  /// Upsert an item.
  Future<void> upsertItem(ItemsCompanion item) async {
    await into(items).insertOnConflictUpdate(item);
  }

  /// Upsert multiple items in a batch.
  Future<void> upsertItems(List<ItemsCompanion> itemList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(items, itemList);
    });
  }

  /// Delete item by ID.
  Future<void> deleteItem(String id) async {
    await (delete(items)..where((t) => t.id.equals(id))).go();
  }

  // Playlist entry queries
  /// Get items for a playlist (position-based sorting).
  Future<List<ItemData>> getPlaylistItemsByPosition(String playlistId) async {
    final query =
        select(items).join([
            innerJoin(
              playlistEntries,
              playlistEntries.itemId.equalsExp(items.id),
            ),
          ])
          ..where(playlistEntries.playlistId.equals(playlistId))
          ..orderBy([
            OrderingTerm(
              expression: playlistEntries.position,
              mode: OrderingMode.asc,
              nulls: NullsOrder.last,
            ),
            OrderingTerm.asc(playlistEntries.itemId),
          ]);

    final result = await query.get();
    return result.map((row) => row.readTable(items)).toList();
  }

  /// Get items for a playlist (provenance-based sorting).
  Future<List<ItemData>> getPlaylistItemsByProvenance(
    String playlistId,
  ) async {
    final query =
        select(items).join([
            innerJoin(
              playlistEntries,
              playlistEntries.itemId.equalsExp(items.id),
            ),
          ])
          ..where(playlistEntries.playlistId.equals(playlistId))
          ..orderBy([
            OrderingTerm.desc(playlistEntries.sortKeyUs),
            OrderingTerm.desc(playlistEntries.itemId),
          ]);

    final result = await query.get();
    return result.map((row) => row.readTable(items)).toList();
  }

  /// Get all items from the database.
  Future<List<ItemData>> getAllItems() async {
    return select(items).get();
  }

  /// Upsert a playlist entry.
  Future<void> upsertPlaylistEntry(PlaylistEntriesCompanion entry) async {
    await into(playlistEntries).insertOnConflictUpdate(entry);
  }

  /// Upsert multiple playlist entries in a batch.
  Future<void> upsertPlaylistEntries(
    List<PlaylistEntriesCompanion> entryList,
  ) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(playlistEntries, entryList);
    });
  }

  /// Delete playlist entries for a playlist.
  Future<void> deletePlaylistEntries(String playlistId) async {
    await (delete(
      playlistEntries,
    )..where((t) => t.playlistId.equals(playlistId))).go();
  }

  /// Delete playlist entry by item ID (across all playlists).
  Future<void> deletePlaylistEntriesByItem(String itemId) async {
    await (delete(playlistEntries)..where((t) => t.itemId.equals(itemId))).go();
  }

  /// Force WAL checkpoint to write pending changes to main database file.
  /// This is useful after bulk writes to ensure data is persisted.
  Future<void> checkpoint() async {
    try {
      await customStatement('PRAGMA wal_checkpoint(PASSIVE)');
      _log.info('WAL checkpoint completed');
    } catch (e) {
      _log.warning('WAL checkpoint failed: $e');
    }
  }
}

/// Opens the database connection.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'playlist_cache.sqlite'));

    _log.info('Opening database at: ${file.path}');

    return NativeDatabase.createInBackground(
      file,
      setup: (db) {
        // Set busy timeout first, before enabling WAL
        db.execute('PRAGMA busy_timeout = 5000');
        
        // Enable WAL mode for better concurrency
        db.execute('PRAGMA journal_mode = WAL');
        
        // Set WAL autocheckpoint to happen more frequently (every 1000 pages, ~4MB)
        db.execute('PRAGMA wal_autocheckpoint = 1000');
        
        _log.info('Database opened with WAL mode enabled');
      },
    );
  });
}
