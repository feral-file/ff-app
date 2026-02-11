import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'app_database.g.dart';

final _log = Logger('AppDatabase');

/// Large limit used when only offset is set (skip N rows, return the rest).
const _maxLimitForOffset = 0x7FFFFFFF;
const _maxReadPoolSize = 4;

/// Main application database using Drift.
/// Implements offline-first storage for DP-1 entities and relationships.
@DriftDatabase(tables: [Channels, Playlists, Items, PlaylistEntries])
class AppDatabase extends _$AppDatabase {
  /// Creates an AppDatabase instance.
  AppDatabase() : super(_openConnection());

  /// Creates an AppDatabase instance from a Drift [DatabaseConnection].
  ///
  /// Used by `computeWithDatabase` to run heavy DB work in a short-lived
  /// isolate while reusing the same sqlite connection.
  AppDatabase.fromConnection(DatabaseConnection e) : super(e);

  /// Creates an AppDatabase instance with a custom executor (for testing).
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _createIndexes();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 3) {
          await _ensureListArtistJsonColumn(m);
        }
      },
      beforeOpen: (OpeningDetails details) async {
        // Ensure list_artist_json exists even if stored version is already 3
        // (e.g. migration ran but addColumn failed, or DB was restored from backup).
        await _ensureListArtistJsonColumn(null);
      },
    );
  }

  /// Idempotent: add items.list_artist_json if missing.
  /// [m] when non-null uses Migrator.addColumn; when null uses raw ALTER TABLE.
  Future<void> _ensureListArtistJsonColumn(Migrator? m) async {
    try {
      if (m != null) {
        await m.addColumn(items, items.listArtistJson);
      } else {
        await customStatement(
          'ALTER TABLE items ADD COLUMN list_artist_json TEXT',
        );
      }
    } catch (e, st) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('duplicate column') || msg.contains('already exists')) {
        _log.fine('list_artist_json already present, skipping');
        return;
      }
      _log.severe('Failed to add list_artist_json', e, st);
      rethrow;
    }
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

  // ===========================================================================
  // Watch queries (reactive streams)
  // ===========================================================================

  /// Watch channels ordered by sort order (then id), optionally filtered by
  /// channel [type] and limited to [limit] rows.
  ///
  /// - [type] matches the `channels.type` integer column.
  /// - [limit] is applied after ordering.
  Stream<List<ChannelData>> watchChannels({
    int? type,
    int? limit,
  }) {
    final query = select(channels)
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.sortOrder,
          mode: OrderingMode.asc,
          nulls: NullsOrder.last,
        ),
        (t) => OrderingTerm.asc(t.id),
      ]);

    if (type != null) {
      query.where((t) => t.type.equals(type));
    }

    if (limit != null) {
      query.limit(limit);
    }

    return query.watch();
  }

  /// Watch playlists ordered by created time (desc, then id), optionally filtered
  /// by playlist [type], [channelId], and limited to [limit] rows.
  ///
  /// - [type] matches the `playlists.type` integer column.
  /// - [limit] is applied after ordering.
  Stream<List<PlaylistData>> watchPlaylists({
    int? type,
    String? channelId,
    String? ownerAddress,
    int? limit,
  }) {
    final query = select(playlists)
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAtUs),
        (t) => OrderingTerm.asc(t.id),
      ]);

    if (type != null) {
      query.where((t) => t.type.equals(type));
    }

    if (channelId != null) {
      query.where((t) => t.channelId.equals(channelId));
    }

    if (ownerAddress != null) {
      query.where((t) => t.ownerAddress.equals(ownerAddress));
    }

    if (limit != null) {
      query.limit(limit);
    }

    return query.watch();
  }

  /// Watch items for a playlist using position-based ordering.
  ///
  /// The results are ordered by:
  /// - `playlist_entries.position` ascending (nulls last)
  /// - `playlist_entries.item_id` ascending (stable tiebreaker)
  Stream<List<ItemData>> watchPlaylistItemsByPosition(
    String playlistId, {
    int? limit,
  }) {
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

    if (limit != null) {
      query.limit(limit);
    }

    return query.watch().map((rows) {
      return rows.map((row) => row.readTable(items)).toList();
    });
  }

  /// Watch items for a playlist using provenance-based ordering.
  ///
  /// The results are ordered by:
  /// - `playlist_entries.sort_key_us` descending
  /// - `playlist_entries.item_id` descending (stable tiebreaker)
  Stream<List<ItemData>> watchPlaylistItemsByProvenance(
    String playlistId, {
    int? limit,
  }) {
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

    if (limit != null) {
      query.limit(limit);
    }

    return query.watch().map((rows) {
      return rows.map((row) => row.readTable(items)).toList();
    });
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

  /// Get channels by type with optional pagination.
  /// Order matches [watchChannels] (sort_order asc, id asc) for consistent paging.
  Future<List<ChannelData>> getChannelsByType(
    int type, {
    int? limit,
    int offset = 0,
  }) async {
    final query = select(channels)
      ..where((t) => t.type.equals(type))
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.sortOrder,
          mode: OrderingMode.asc,
          nulls: NullsOrder.last,
        ),
        (t) => OrderingTerm.asc(t.id),
      ]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.get();
  }

  /// Get channel by ID.
  Future<ChannelData?> getChannelById(String id) async {
    return (select(channels)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch a single channel by ID. Emits null if the channel is deleted.
  Stream<ChannelData?> watchChannelById(String id) {
    return (select(channels)..where((t) => t.id.equals(id)))
        .watch()
        .map((list) => list.isEmpty ? null : list.single);
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

  /// Delete playlist by ID.
  Future<void> deletePlaylist(String playlistId) async {
    await (delete(playlists)..where((t) => t.id.equals(playlistId))).go();
  }

  // Item queries
  /// Get item by ID.
  Future<ItemData?> getItemById(String id) async {
    return (select(items)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch a single item by ID; emits when the row changes or is removed.
  Stream<ItemData?> watchItemById(String id) {
    return (select(items)..where((t) => t.id.equals(id)))
        .watch()
        .map((list) => list.isNotEmpty ? list.first : null);
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
  /// [limit] null = return all; [offset] null = 0.
  Future<List<ItemData>> getPlaylistItemsByPosition(
    String playlistId, {
    int? limit,
    int? offset,
  }) async {
    final off = offset ?? 0;
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

    if (limit != null) {
      query.limit(limit, offset: off);
    }
    final result = await query.get();
    return result.map((row) => row.readTable(items)).toList();
  }

  /// Get items for a playlist (provenance-based sorting).
  /// [limit] null = return all; [offset] null = 0.
  Future<List<ItemData>> getPlaylistItemsByProvenance(
    String playlistId, {
    int? limit,
    int? offset,
  }) async {
    final off = offset ?? 0;
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

    if (limit != null) {
      query.limit(limit, offset: off);
    }
    final result = await query.get();
    return result.map((row) => row.readTable(items)).toList();
  }

  /// Get playlist items for a channel (join playlists → playlist_entries → items).
  /// Ordered by playlist created time, playlist id, then item position.
  /// [limit] null = return all; [offset] null = 0.
  /// Returns empty if playlists have null channel_id; set channelId when
  /// ingesting DP1 playlists in channel context (e.g. reloadCache with channels).
  Future<List<ItemData>> getPlaylistItemsByChannel(
    String channelId, {
    int? limit,
    int? offset,
  }) async {
    final off = offset ?? 0;
    final query =
        select(items).join([
            innerJoin(
              playlistEntries,
              playlistEntries.itemId.equalsExp(items.id),
            ),
            innerJoin(
              playlists,
              playlists.id.equalsExp(playlistEntries.playlistId),
            ),
          ])
          ..where(playlists.channelId.equals(channelId))
          ..orderBy([
            OrderingTerm.asc(playlists.createdAtUs),
            OrderingTerm.asc(playlists.id),
            OrderingTerm(
              expression: playlistEntries.position,
              mode: OrderingMode.asc,
              nulls: NullsOrder.last,
            ),
            OrderingTerm.asc(playlistEntries.itemId),
          ]);

    if (limit != null) {
      query.limit(limit, offset: off);
    }

    final result = await query.get();
    return result.map((row) => row.readTable(items)).toList();
  }

  /// Watch playlist items for a channel (same join as [getPlaylistItemsByChannel]).
  /// Emits when playlists, playlist_entries, or items matching the channel change.
  Stream<List<ItemData>> watchPlaylistItemsByChannel(
    String channelId, {
    int? limit,
    int? offset,
  }) {
    final off = offset ?? 0;
    final query =
        select(items).join([
            innerJoin(
              playlistEntries,
              playlistEntries.itemId.equalsExp(items.id),
            ),
            innerJoin(
              playlists,
              playlists.id.equalsExp(playlistEntries.playlistId),
            ),
          ])
          ..where(playlists.channelId.equals(channelId))
          ..orderBy([
            OrderingTerm.asc(playlists.createdAtUs),
            OrderingTerm.asc(playlists.id),
            OrderingTerm(
              expression: playlistEntries.position,
              mode: OrderingMode.asc,
              nulls: NullsOrder.last,
            ),
            OrderingTerm.asc(playlistEntries.itemId),
          ]);

    if (limit != null) {
      query.limit(limit, offset: off);
    }

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(items)).toList(),
    );
  }

  /// Get all items from the database.
  Future<List<ItemData>> getAllItems() async {
    return select(items).get();
  }

  /// Get items with optional [limit] and [offset] for paging.
  /// When both are null, returns all (same as [getAllItems]).
  Future<List<ItemData>> getItems({int? limit, int? offset}) async {
    final off = offset ?? 0;
    final query = select(items)
      ..orderBy([
        (t) => OrderingTerm.asc(t.id),
      ]);
    if (limit != null) {
      return (query..limit(limit, offset: off)).get();
    }
    if (off > 0) {
      return (query..limit(_maxLimitForOffset, offset: off)).get();
    }
    return query.get();
  }

  /// Watch all items; emits when the items table changes.
  Stream<List<ItemData>> watchAllItems() {
    final query = select(items)
      ..orderBy([
        (t) => OrderingTerm.asc(t.id),
      ]);
    return query.watch();
  }

  /// Get ordered item IDs with optional [limit] and [offset].
  /// Uses the same ordering as [getItems] so pagination and diff windows align.
  Future<List<String>> getItemIds({int? limit, int? offset}) async {
    final off = offset ?? 0;
    final query = selectOnly(items)
      ..addColumns([items.id])
      ..orderBy([
        OrderingTerm.asc(items.id),
      ]);
    if (limit != null) {
      query.limit(limit, offset: off);
    } else if (off > 0) {
      query.limit(_maxLimitForOffset, offset: off);
    }

    final rows = await query.get();
    return rows
        .map((row) => row.read(items.id))
        .whereType<String>()
        .toList(growable: false);
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

  /// Delete a single playlist entry by playlist ID and item ID.
  Future<void> deletePlaylistEntry({
    required String playlistId,
    required String itemId,
  }) async {
    await (delete(playlistEntries)..where(
          (t) => t.playlistId.equals(playlistId) & t.itemId.equals(itemId),
        ))
        .go();
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

  /// Get playlists by baseUrls with order (first baseUrl's playlists first),
  /// then by createdAt ASC within each baseUrl.
  /// Matches old repo's getPlaylistRowsByBaseUrls query.
  /// Order, limit and offset are applied in the query (no in-memory sort/slice).
  /// - [baseUrls] order matters.
  /// - [type] 0 = DP1, 1 = address (null = all).
  /// - [offset] and [limit] for pagination.
  Future<List<PlaylistData>> getPlaylistsByBaseUrlsOrdered({
    required List<String> baseUrls,
    int? type,
    int? offset,
    int? limit,
  }) async {
    if (baseUrls.isEmpty) return [];

    // ORDER BY baseUrl order (CASE expression), then created_at_us, then id.
    final baseUrlOrderExpr = playlists.baseUrl.caseMatch(
      when: Map.fromEntries(
        baseUrls.asMap().entries.map(
          (e) => MapEntry(Variable.withString(e.value), Constant(e.key)),
        ),
      ),
      orElse: Constant(baseUrls.length),
    );

    final query = select(playlists)
      ..where(
        (p) =>
            p.baseUrl.isIn(baseUrls) &
            (type != null ? p.type.equals(type) : const Constant(true)),
      )
      ..orderBy([
        (p) => OrderingTerm.asc(baseUrlOrderExpr),
        (p) => OrderingTerm.asc(p.createdAtUs),
        (p) => OrderingTerm.asc(p.id),
      ]);

    if (limit != null) {
      query.limit(limit, offset: offset ?? 0);
    } else if (offset != null && offset > 0) {
      query.limit(_maxLimitForOffset, offset: offset);
    }

    return query.get();
  }

  /// Delete all playlists of given type and baseUrl.
  /// Matches old repo's deleteAllPlaylists(kind, baseUrl).
  Future<int> deletePlaylistsByTypeAndBaseUrl({
    required int type,
    required String baseUrl,
  }) async {
    return (delete(
      playlists,
    )..where((p) => p.type.equals(type) & p.baseUrl.equals(baseUrl))).go();
  }

  /// Delete all channels of given type and baseUrl.
  /// Matches old repo's deleteAllChannels(kind, baseUrl).
  Future<int> deleteChannelsByTypeAndBaseUrl({
    required int type,
    required String baseUrl,
  }) async {
    return (delete(
      channels,
    )..where((c) => c.type.equals(type) & c.baseUrl.equals(baseUrl))).go();
  }
}

/// Opens the database connection.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'playlist_cache.sqlite'));
    final readPoolSize = _resolveReadPoolSize();

    _log.info(
      'Opening database at: ${file.path} '
      '(write isolate + $readPoolSize read isolates)',
    );

    return NativeDatabase.createInBackground(
      file,
      readPool: readPoolSize,
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

int _resolveReadPoolSize() {
  // Keep one core for UI/other async work, then cap reader isolates.
  final availableForReaders = Platform.numberOfProcessors - 2;
  if (availableForReaders <= 0) {
    return 0;
  }
  return availableForReaders > _maxReadPoolSize
      ? _maxReadPoolSize
      : availableForReaders;
}
