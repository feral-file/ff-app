import 'dart:io';

import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/database/tables.dart';
import 'package:drift/drift.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_drift/sentry_drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

part 'app_database.g.dart';

final _log = Logger('AppDatabase');

/// Large limit used when only offset is set (skip N rows, return the rest).
const _maxLimitForOffset = 0x7FFFFFFF;
const _schemaVersionV1 = 3;
const _dbResetReindexMarkerFile = 'db_reset_requires_reindex.flag';

/// Main application database using Drift.
/// Implements offline-first storage for DP-1 entities and relationships.
@DriftDatabase(
  tables: [Publishers, Channels, Playlists, Items, PlaylistEntries],
)
class AppDatabase extends _$AppDatabase {
  /// Creates an AppDatabase instance.
  AppDatabase() : super(_openConnection());

  /// Creates an AppDatabase instance from a Drift [DatabaseConnection].
  ///
  /// Used by `computeWithDatabase` to run heavy DB work in a short-lived
  /// isolate while reusing the same sqlite connection.
  AppDatabase.fromConnection(DatabaseConnection super.e);

  /// Creates an AppDatabase instance with a custom executor (for testing).
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => _schemaVersionV1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        await _createIndexes();
        await _createFtsInfrastructure();
        await _rebuildFtsIndexes();
      },
      onUpgrade: (m, from, to) async {
        if (from < 3) {
          await m.addColumn(items, items.enrichmentStatus);
        }
      },
      beforeOpen: (details) async {
        await _createIndexes();
        await _createFtsInfrastructure();
        if (details.wasCreated || details.hadUpgrade) {
          await _rebuildFtsIndexes();
        }
      },
    );
  }

  /// Creates performance indexes.
  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_channels_publisher '
      'ON channels(publisher_id)',
    );

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
      'CREATE INDEX IF NOT EXISTS idx_playlists_type_channel_created '
      'ON playlists(type, channel_id, created_at_us)',
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

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entries_item '
      'ON playlist_entries(item_id, playlist_id)',
    );
  }

  Future<void> _createFtsInfrastructure() async {
    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS channels_fts
      USING fts5(
        id UNINDEXED,
        title,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');

    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS playlists_fts
      USING fts5(
        id UNINDEXED,
        title,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');

    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS items_fts
      USING fts5(
        id UNINDEXED,
        title,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');

    await customStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS item_artists_fts
      USING fts5(
        id UNINDEXED,
        artist_name,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS channels_ai AFTER INSERT ON channels BEGIN
        INSERT INTO channels_fts(id, title) VALUES (new.id, new.title);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS channels_ad AFTER DELETE ON channels BEGIN
        DELETE FROM channels_fts WHERE id = old.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS channels_au AFTER UPDATE ON channels BEGIN
        DELETE FROM channels_fts WHERE id = old.id;
        INSERT INTO channels_fts(id, title) VALUES (new.id, new.title);
      END
    ''');

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS playlists_ai AFTER INSERT ON playlists BEGIN
        INSERT INTO playlists_fts(id, title) VALUES (new.id, new.title);
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS playlists_ad AFTER DELETE ON playlists BEGIN
        DELETE FROM playlists_fts WHERE id = old.id;
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS playlists_au AFTER UPDATE ON playlists BEGIN
        DELETE FROM playlists_fts WHERE id = old.id;
        INSERT INTO playlists_fts(id, title) VALUES (new.id, new.title);
      END
    ''');

    await customStatement(r'''
      CREATE TRIGGER IF NOT EXISTS items_ai AFTER INSERT ON items BEGIN
        INSERT INTO items_fts(id, title) VALUES (new.id, COALESCE(new.title, ''));
        INSERT INTO item_artists_fts(id, artist_name)
        SELECT new.id, COALESCE(json_extract(j.value, '$.name'), '')
        FROM json_each(
          CASE
            WHEN json_valid(new.list_artist_json) THEN new.list_artist_json
            ELSE '[]'
          END
        ) AS j
        WHERE COALESCE(json_extract(j.value, '$.name'), '') != '';
      END
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS items_ad AFTER DELETE ON items BEGIN
        DELETE FROM items_fts WHERE id = old.id;
        DELETE FROM item_artists_fts WHERE id = old.id;
      END
    ''');
    await customStatement(r'''
      CREATE TRIGGER IF NOT EXISTS items_au AFTER UPDATE ON items BEGIN
        DELETE FROM items_fts WHERE id = old.id;
        INSERT INTO items_fts(id, title) VALUES (new.id, COALESCE(new.title, ''));
        DELETE FROM item_artists_fts WHERE id = old.id;
        INSERT INTO item_artists_fts(id, artist_name)
        SELECT new.id, COALESCE(json_extract(j.value, '$.name'), '')
        FROM json_each(
          CASE
            WHEN json_valid(new.list_artist_json) THEN new.list_artist_json
            ELSE '[]'
          END
        ) AS j
        WHERE COALESCE(json_extract(j.value, '$.name'), '') != '';
      END
    ''');
  }

  Future<void> _rebuildFtsIndexes() async {
    await customStatement('DELETE FROM channels_fts');
    await customStatement(
      'INSERT INTO channels_fts(id, title) '
      'SELECT id, title FROM channels',
    );

    await customStatement('DELETE FROM playlists_fts');
    await customStatement(
      'INSERT INTO playlists_fts(id, title) '
      'SELECT id, title FROM playlists',
    );

    await customStatement('DELETE FROM items_fts');
    await customStatement(
      'INSERT INTO items_fts(id, title) '
      "SELECT id, COALESCE(title, '') FROM items",
    );

    await customStatement('DELETE FROM item_artists_fts');
    await customStatement(r'''
      INSERT INTO item_artists_fts(id, artist_name)
      SELECT i.id, COALESCE(json_extract(j.value, '$.name'), '')
      FROM items i,
           json_each(
             CASE
               WHEN json_valid(i.list_artist_json) THEN i.list_artist_json
               ELSE '[]'
             END
           ) j
      WHERE COALESCE(json_extract(j.value, '$.name'), '') != ''
    ''');
  }

  String _buildFtsMatchQuery(String rawQuery) {
    final tokens = rawQuery
        .trim()
        .split(RegExp(r'\s+'))
        .map((token) => token.replaceAll(RegExp('[^A-Za-z0-9_]'), ''))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return '';
    }
    return tokens.map((token) => '"$token"*').join(' ');
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
    const publisherOrderExpr = CustomExpression<int>(
      'COALESCE(channels.publisher_id, 2147483647)',
    );
    final query = select(channels)
      ..orderBy([
        (t) => OrderingTerm.asc(publisherOrderExpr),
        (t) => OrderingTerm(
          expression: t.sortOrder,
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

  /// Watch playlists ordered by created time (desc, then id), optionally
  /// filtered
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
    const publisherOrderExpr = CustomExpression<int>(
      '''
      COALESCE(
        (
          SELECT c.publisher_id
          FROM channels c
          WHERE c.id = playlists.channel_id
        ),
        2147483647
      )
      ''',
    );
    final query = select(playlists)
      ..orderBy([
        (t) => OrderingTerm.asc(publisherOrderExpr),
        (t) => OrderingTerm.asc(t.createdAtUs),
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
    const publisherOrderExpr = CustomExpression<int>(
      'COALESCE(channels.publisher_id, 2147483647)',
    );
    return (select(channels)..orderBy([
          (t) => OrderingTerm.asc(publisherOrderExpr),
          (t) => OrderingTerm(
            expression: t.sortOrder,
            nulls: NullsOrder.last,
          ),
          (t) => OrderingTerm.asc(t.id),
        ]))
        .get();
  }

  /// Get channels by type with optional pagination.
  /// Order matches [watchChannels] (sort_order asc, id asc) for consistent
  /// paging.
  Future<List<ChannelData>> getChannelsByType(
    int type, {
    int? limit,
    int offset = 0,
  }) async {
    const publisherOrderExpr = CustomExpression<int>(
      'COALESCE(channels.publisher_id, 2147483647)',
    );
    final query = select(channels)
      ..where((t) => t.type.equals(type))
      ..orderBy([
        (t) => OrderingTerm.asc(publisherOrderExpr),
        (t) => OrderingTerm(
          expression: t.sortOrder,
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
    return (select(channels)..where((t) => t.id.equals(id))).watch().map(
      (list) => list.isEmpty ? null : list.single,
    );
  }

  /// Upsert a channel.
  Future<void> upsertChannel(ChannelsCompanion channel) async {
    await into(channels).insertOnConflictUpdate(channel);
  }

  /// Upsert a publisher.
  Future<void> upsertPublisher(PublishersCompanion publisher) async {
    await into(publishers).insertOnConflictUpdate(publisher);
  }

  /// Upsert multiple publishers in a batch.
  Future<void> upsertPublishers(List<PublishersCompanion> publisherList) async {
    await batch((batch) {
      batch.insertAllOnConflictUpdate(publishers, publisherList);
    });
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

  /// Watch a single playlist by ID.
  Stream<PlaylistData?> watchPlaylistById(String id) {
    return (select(playlists)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Get all playlists.
  ///
  /// When [type] is provided, results are filtered by playlist type:
  /// - 0 = DP1
  /// - 1 = address-based
  Future<List<PlaylistData>> getAllPlaylists({PlaylistType? type}) async {
    final variables = <Variable<Object>>[];
    final whereClause = type == null
        ? ''
        : (() {
            variables.add(Variable<int>(type.value));
            return 'WHERE p.type = ?';
          })();

    final result = await customSelect(
      '''
      SELECT p.*
      FROM playlists p
      LEFT JOIN channels c ON c.id = p.channel_id
      $whereClause
      ORDER BY COALESCE(c.publisher_id, 2147483647) ASC, p.created_at_us ASC
      ''',
      variables: variables,
      readsFrom: {playlists, channels},
    ).map((row) => playlists.map(row.data)).get();

    return result;
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
    return (select(items)..where((t) => t.id.equals(id))).watch().map(
      (list) => list.isNotEmpty ? list.first : null,
    );
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
  ///
  /// When [force] is true (default), conflicts overwrite existing rows.
  /// When [force] is false, existing rows are preserved (INSERT OR IGNORE).
  Future<void> upsertItems(
    List<ItemsCompanion> itemList, {
    bool force = true,
  }) async {
    await batch((batch) {
      if (force) {
        batch.insertAllOnConflictUpdate(items, itemList);
      } else {
        batch.insertAll(items, itemList, mode: InsertMode.insertOrIgnore);
      }
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

  /// Get playlist items for a channel
  /// (join playlists → playlist_entries → items).
  /// Ordered by playlist created time, playlist id, then item position.
  /// [limit] null = return all; [offset] null = 0.
  /// Returns empty if playlists have null channel_id; set channelId when
  /// ingesting DP1 playlists in channel context
  /// (e.g. reloadCache with channels).
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

  /// Watch playlist items for a channel
  /// (same join as [getPlaylistItemsByChannel]).
  /// Emits when playlists, playlist_entries, or items matching the channel
  /// change.
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

  /// Full-text search channels by title.
  Future<List<ChannelData>> searchChannelsByTitleFts(
    String query, {
    int limit = 20,
  }) async {
    final matchQuery = _buildFtsMatchQuery(query);
    if (matchQuery.isEmpty) {
      return const [];
    }

    final rows = await customSelect(
      '''
      SELECT c.*
      FROM channels_fts f
      INNER JOIN channels c ON c.id = f.id
      WHERE channels_fts MATCH ?
      ORDER BY bm25(channels_fts), c.sort_order ASC, c.id ASC
      LIMIT ?
      ''',
      variables: [
        Variable.withString(matchQuery),
        Variable.withInt(limit),
      ],
      readsFrom: {channels},
    ).get();

    return rows.map((row) => channels.map(row.data)).toList();
  }

  /// Full-text search playlists by title.
  Future<List<PlaylistData>> searchPlaylistsByTitleFts(
    String query, {
    int limit = 20,
  }) async {
    final matchQuery = _buildFtsMatchQuery(query);
    if (matchQuery.isEmpty) {
      return const [];
    }

    final rows = await customSelect(
      '''
      SELECT p.*
      FROM playlists_fts f
      INNER JOIN playlists p ON p.id = f.id
      WHERE playlists_fts MATCH ?
      ORDER BY bm25(playlists_fts), p.created_at_us DESC, p.id ASC
      LIMIT ?
      ''',
      variables: [
        Variable.withString(matchQuery),
        Variable.withInt(limit),
      ],
      readsFrom: {playlists},
    ).get();

    return rows.map((row) => playlists.map(row.data)).toList();
  }

  /// Full-text search items by title.
  Future<List<ItemData>> searchItemsByTitleFts(
    String query, {
    int limit = 20,
  }) async {
    final matchQuery = _buildFtsMatchQuery(query);
    if (matchQuery.isEmpty) {
      return const [];
    }

    final rows = await customSelect(
      '''
      WITH matched_items AS (
        SELECT f.id AS item_id, bm25(items_fts) AS rank
        FROM items_fts f
        WHERE items_fts MATCH ?
        UNION ALL
        SELECT f.id AS item_id, bm25(item_artists_fts) AS rank
        FROM item_artists_fts f
        WHERE item_artists_fts MATCH ?
      ),
      ranked_items AS (
        SELECT item_id, MIN(rank) AS rank
        FROM matched_items
        GROUP BY item_id
      )
      SELECT i.*
      FROM ranked_items r
      INNER JOIN items i ON i.id = r.item_id
      ORDER BY r.rank ASC, i.updated_at_us DESC, i.id ASC
      LIMIT ?
      ''',
      variables: [
        Variable.withString(matchQuery),
        Variable.withString(matchQuery),
        Variable.withInt(limit),
      ],
      readsFrom: {items},
    ).get();

    return rows.map((row) => items.map(row.data)).toList();
  }

  /// Get items with optional [limit] and [offset] for paging.
  /// When both are null, returns all (same as [getAllItems]).
  Future<List<ItemData>> getItems({int? limit, int? offset}) async {
    final orderedIds = await _getOrderedItemIds(limit: limit, offset: offset);
    if (orderedIds.isEmpty) return const <ItemData>[];

    final rows = await getItemsByIds(orderedIds);
    final rowsById = <String, ItemData>{
      for (final row in rows) row.id: row,
    };
    return orderedIds
        .map((id) => rowsById[id])
        .whereType<ItemData>()
        .toList(growable: false);
  }

  /// Watch all items; emits when the items table changes.
  Stream<List<ItemData>> watchAllItems() {
    // Works provider only uses this stream as a "data changed" signal.
    // Keep query lightweight to avoid expensive per-row ranking
    // on every change.
    final query = select(items)..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return query.watch();
  }

  /// Watch a lightweight revision signal for the items table.
  ///
  /// Emits the current item count and re-emits whenever rows in [items] change.
  /// This avoids materializing all rows when callers only need change
  /// notifications.
  Stream<int> watchItemsRevisionSignal() {
    final countExpr = items.id.count();
    final query = selectOnly(items)..addColumns([countExpr]);
    return query.watchSingle().map((row) => row.read(countExpr) ?? 0);
  }

  /// Get ordered item IDs with optional [limit] and [offset].
  /// Uses the same ordering as [getItems] so pagination and diff windows align.
  Future<List<String>> getItemIds({int? limit, int? offset}) async {
    return _getOrderedItemIds(limit: limit, offset: offset);
  }

  Future<List<String>> _getOrderedItemIds({int? limit, int? offset}) async {
    final off = offset ?? 0;
    final limitClause = limit != null || off > 0 ? 'LIMIT ? OFFSET ?' : '';
    final variables = <Variable<Object>>[];
    if (limit != null || off > 0) {
      variables
        ..add(Variable.withInt(limit ?? _maxLimitForOffset))
        ..add(Variable.withInt(off));
    }

    final query = customSelect(
      '''
      WITH item_rank AS (
        SELECT
          pe.item_id AS item_id,
          MIN(COALESCE(c.publisher_id, 2147483647)) AS publisher_order,
          MIN(COALESCE(c.created_at_us, 9223372036854775807)) AS channel_created_at_order,
          MIN(COALESCE(p.created_at_us, 9223372036854775807)) AS playlist_created_at_order
        FROM playlist_entries pe
        JOIN playlists p ON p.id = pe.playlist_id
        LEFT JOIN channels c ON c.id = p.channel_id
        GROUP BY pe.item_id
      )
      SELECT i.id AS id
      FROM items i
      LEFT JOIN item_rank r ON r.item_id = i.id
      ORDER BY
        COALESCE(r.publisher_order, 2147483647) ASC,
        COALESCE(r.channel_created_at_order, 9223372036854775807) ASC,
        COALESCE(r.playlist_created_at_order, 9223372036854775807) ASC,
        i.id ASC
      $limitClause
      ''',
      variables: variables,
      readsFrom: {items, playlists, channels, playlistEntries},
    );

    final rows = await query.get();
    return rows
        .map((row) => row.read<String>('id'))
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

  Selectable<PlaylistEntryData> _playlistEntryQuery(
    String playlistId,
    String itemId,
  ) =>
      (select(playlistEntries)
            ..where(
              (t) =>
                  t.playlistId.equals(playlistId) & t.itemId.equals(itemId),
            ));

  /// Check whether a playlist entry exists.
  Future<bool> hasPlaylistEntry({
    required String playlistId,
    required String itemId,
  }) async {
    final entry =
        await _playlistEntryQuery(playlistId, itemId).getSingleOrNull();
    return entry != null;
  }

  /// Watch whether a playlist entry exists.
  /// Emits true when the entry exists, false when it does not.
  Stream<bool> watchHasPlaylistEntry({
    required String playlistId,
    required String itemId,
  }) =>
      _playlistEntryQuery(playlistId, itemId)
          .watchSingleOrNull()
          .map((entry) => entry != null);

  /// Delete playlist entries for address-based playlists.
  ///
  /// Items are not deleted; orphaned items stay in the database.
  /// [addresses] must be pre-normalized by the caller.
  Future<void> deleteItemsAndEntriesOfAddresses(List<String> addresses) async {
    if (addresses.isEmpty) return;
    final placeholders = addresses.map((_) => '?').join(',');
    await customStatement(
      'DELETE FROM playlist_entries WHERE playlist_id IN ( '
      'SELECT id FROM playlists '
      'WHERE type = 1 '
      "AND LOWER(TRIM(COALESCE(owner_address, ''))) IN ($placeholders))",
      addresses,
    );
  }

  /// Force WAL checkpoint to write pending changes to main database file.
  /// This is useful after bulk writes to ensure data is persisted.
  Future<void> checkpoint() async {
    try {
      await customStatement('PRAGMA wal_checkpoint(PASSIVE)');
      _log.info('WAL checkpoint completed');
    } on Object catch (e) {
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
    const publisherOrderExpr = CustomExpression<int>(
      '''
      COALESCE(
        (
          SELECT c.publisher_id
          FROM channels c
          WHERE c.id = playlists.channel_id
        ),
        2147483647
      )
      ''',
    );

    final query = select(playlists)
      ..where(
        (p) =>
            p.baseUrl.isIn(baseUrls) &
            (type != null ? p.type.equals(type) : const Constant(true)),
      )
      ..orderBy([
        (p) => OrderingTerm.asc(publisherOrderExpr),
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
  /// Deletes playlist_entries first to avoid orphaned rows.
  Future<int> deletePlaylistsByTypeAndBaseUrl({
    required PlaylistType type,
    required String baseUrl,
  }) async {
    await customStatement(
      'DELETE FROM playlist_entries WHERE playlist_id IN ( '
      'SELECT id FROM playlists WHERE type = ? AND base_url = ?)',
      [type.value, baseUrl],
    );
    return (delete(
          playlists,
        )..where((p) => p.type.equals(type.value) & p.baseUrl.equals(baseUrl)))
        .go();
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
// Creates the NativeDatabase executor for a given file with standard PRAGMAs.
NativeDatabase _makeNativeDatabase(File file) {
  return NativeDatabase(
    file,
    setup: (db) {
      db
        ..execute('PRAGMA busy_timeout = 5000')
        ..execute('PRAGMA journal_mode = WAL')
        ..execute('PRAGMA wal_autocheckpoint = 1000');
      _log.info('Database opened with WAL mode enabled');
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    // Wait for the seed database to be placed before opening the connection.
    // On a fresh install this suspends until SeedDownloadNotifier completes
    // (success or failure). On subsequent launches SeedDatabaseGate is
    // completed immediately in main(), so there is zero delay.
    await SeedDatabaseGate.future;

    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dp1_library.sqlite'));
    final wasDeletedForSchemaConflict =
        await _resetDatabaseIfSchemaConflicts(file, dbFolder);

    // Never create an empty database in the normal flow. The app only uses
    // the seed: download to temp dir, then replace current DB file. If the
    // file is missing (e.g. download failed on first install), refuse to
    // open. Schema conflict recovery may have deleted the file; in that
    // edge case we allow SQLite to create (Drift onCreate) as fallback.
    if (!file.existsSync() && !wasDeletedForSchemaConflict) {
      throw StateError(
        'Seed database file is missing at ${file.path}. '
        'The app requires the seed to be downloaded; creating an empty '
        'database is not supported.',
      );
    }

    _log.info('Opening database at: ${file.path}');

    // Run SQLite work on a background Drift isolate.
    // singleClientMode: true ensures the isolate shuts down when the connection
    // is closed (e.g. during Forget I Exist), preventing accumulation of orphan
    // isolates.
    try {
      final driftIsolate = await DriftIsolate.spawn(
        () => _makeNativeDatabase(file),
      );
      final connection = await driftIsolate.connect(singleClientMode: true);
      return connection.interceptWith(
        SentryQueryInterceptor(databaseName: file.path),
      );
    } on Object catch (e, st) {
      _log.warning(
        'Failed to open database. Recreating from scratch and retrying once.',
        e,
        st,
      );
      await _deleteDatabaseFiles(file);
      await _markDatabaseResetForReindex(dbFolder);
      final driftIsolate = await DriftIsolate.spawn(
        () => _makeNativeDatabase(file),
      );
      final connection = await driftIsolate.connect(singleClientMode: true);
      return connection.interceptWith(
        SentryQueryInterceptor(databaseName: file.path),
      );
    }
  });
}

/// Returns true if the database file was deleted due to schema conflict.
/// Caller may allow SQLite to create a fresh DB in that edge case.
Future<bool> _resetDatabaseIfSchemaConflicts(
  File dbFile,
  Directory dbFolder,
) async {
  if (!dbFile.existsSync()) {
    return false;
  }

  sqlite3.Database? probeDb;
  try {
    probeDb = sqlite3.sqlite3.open(dbFile.path);
    final rows = probeDb.select('PRAGMA user_version');
    final userVersion = rows.isEmpty ? 0 : (rows.first.columnAt(0) as int);
    final schemaCompatible = _isSchemaCompatibleV1(probeDb);
    if (userVersion == _schemaVersionV1 && schemaCompatible) {
      return false;
    }

    _log.warning(
      'Schema conflict detected (found user_version=$userVersion, '
      'expected=$_schemaVersionV1, compatible=$schemaCompatible). '
      'Recreating database from scratch.',
    );
    await _deleteDatabaseFiles(dbFile);
    await _markDatabaseResetForReindex(dbFolder);
    return true;
  } on Object catch (e, st) {
    _log.warning(
      'Failed to read schema version. Recreating database from scratch.',
      e,
      st,
    );
    await _deleteDatabaseFiles(dbFile);
    await _markDatabaseResetForReindex(dbFolder);
    return true;
  } finally {
    probeDb?.dispose();
  }
}

bool _isSchemaCompatibleV1(sqlite3.Database db) {
  const requiredTables = <String>{
    'publishers',
    'channels',
    'playlists',
    'items',
    'playlist_entries',
  };

  final existingTables = db
      .select("SELECT name FROM sqlite_master WHERE type = 'table'")
      .map((row) => row.columnAt(0).toString())
      .toSet();
  if (!existingTables.containsAll(requiredTables)) {
    return false;
  }

  if (!_tableHasColumn(db, 'channels', 'publisher_id')) {
    return false;
  }
  if (!_tableHasColumn(db, 'items', 'list_artist_json')) {
    return false;
  }
  if (!_tableHasColumn(db, 'items', 'enrichment_status')) {
    return false;
  }

  return true;
}

bool _tableHasColumn(sqlite3.Database db, String table, String column) {
  final rows = db.select('PRAGMA table_info($table)');
  for (final row in rows) {
    final name = row.columnAt(1).toString();
    if (name == column) {
      return true;
    }
  }
  return false;
}

Future<void> _deleteDatabaseFiles(File dbFile) async {
  final wal = File('${dbFile.path}-wal');
  final shm = File('${dbFile.path}-shm');
  for (final f in <File>[dbFile, wal, shm]) {
    if (f.existsSync()) {
      await f.delete();
    }
  }
}

Future<void> _markDatabaseResetForReindex(Directory dbFolder) async {
  final marker = File(p.join(dbFolder.path, _dbResetReindexMarkerFile));
  await marker.writeAsString(DateTime.now().toUtc().toIso8601String());
}

/// Returns true when a schema-conflict reset happened and clears the marker.
Future<bool> consumeDatabaseResetReindexMarker() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final marker = File(p.join(dbFolder.path, _dbResetReindexMarkerFile));
  if (!marker.existsSync()) {
    return false;
  }
  await marker.delete();
  return true;
}
