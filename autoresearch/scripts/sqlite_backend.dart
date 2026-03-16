import 'package:sqlite3/sqlite3.dart';

import 'benchmark_core.dart';

class SqliteBenchmarkBackend {
  SqliteBenchmarkBackend({
    required this.db,
    required this.databasePath,
  });

  final Database db;
  final String databasePath;

  String get backendName => 'sqlite';

  List<BenchmarkScenario> buildScenarios() {
    final channels = db.select(
      '''
      SELECT id, title
      FROM channels
      WHERE type = 0
      ORDER BY
        COALESCE(publisher_id, 2147483647) ASC,
        sort_order IS NULL ASC,
        sort_order ASC,
        id ASC
      LIMIT 20
      ''',
    );
    final playlists = db.select(
      '''
      SELECT id, title, sort_mode
      FROM playlists
      WHERE type = 0
      ORDER BY
        COALESCE(
          (
            SELECT c.publisher_id
            FROM channels c
            WHERE c.id = playlists.channel_id
          ),
          2147483647
        ) ASC,
        created_at_us ASC
      ''',
    );
    final works = _getItems(limit: 100, offset: 0);

    if (channels.isEmpty || playlists.isEmpty || works.isEmpty) {
      throw StateError(
        'Benchmark requires non-empty channels, playlists, and works. '
        'channels=${channels.length}, playlists=${playlists.length}, '
        'works=${works.length}',
      );
    }

    final positionPlaylist = playlists.firstWhere(
      (row) => row['sort_mode'] == 0,
      orElse: () => playlists.first,
    );
    final provenancePlaylist = playlists.firstWhere(
      (row) => row['sort_mode'] == 1,
      orElse: () => positionPlaylist,
    );
    final sampleChannelId = channels.first['id'] as String;
    final sampleChannelTitle = channels.first['title'] as String? ?? '';
    final samplePlaylistId = positionPlaylist['id'] as String;
    final samplePlaylistTitle = positionPlaylist['title'] as String? ?? '';
    final sampleProvenancePlaylistId = provenancePlaylist['id'] as String;
    final sampleItemId = works.first['id'] as String;
    final sampleItemTitle = works.first['title'] as String? ?? '';

    return [
      BenchmarkScenario(
        name: 'channels.dp1.page1.limit11',
        runner: () => db.select(
          '''
          SELECT *
          FROM channels
          WHERE type = 0
          ORDER BY
            COALESCE(publisher_id, 2147483647) ASC,
            sort_order IS NULL ASC,
            sort_order ASC,
            id ASC
          LIMIT 11
          ''',
        ),
      ),
      BenchmarkScenario(
        name: 'channels.dp1.page2.limit10',
        runner: () => db.select(
          '''
          SELECT *
          FROM channels
          WHERE type = 0
          ORDER BY
            COALESCE(publisher_id, 2147483647) ASC,
            sort_order IS NULL ASC,
            sort_order ASC,
            id ASC
          LIMIT 10 OFFSET 10
          ''',
        ),
      ),
      BenchmarkScenario(
        name: 'playlists.dp1.all',
        runner: () => db.select(
          '''
          SELECT p.*
          FROM playlists p
          LEFT JOIN channels c ON c.id = p.channel_id
          WHERE p.type = 0
          ORDER BY COALESCE(c.publisher_id, 2147483647) ASC, p.created_at_us ASC
          ''',
        ),
      ),
      BenchmarkScenario(
        name: 'channel.detail',
        runner: () => db.select(
          'SELECT * FROM channels WHERE id = ? LIMIT 1',
          [sampleChannelId],
        ),
      ),
      BenchmarkScenario(
        name: 'playlist.detail',
        runner: () => db.select(
          'SELECT * FROM playlists WHERE id = ? LIMIT 1',
          [samplePlaylistId],
        ),
      ),
      BenchmarkScenario(
        name: 'playlist.items.position.page1',
        runner: () => _getPlaylistItemsByPosition(
          playlistId: samplePlaylistId,
          limit: 20,
          offset: 0,
        ),
      ),
      BenchmarkScenario(
        name: 'playlist.items.position.full',
        runner: () => _getPlaylistItemsByPosition(playlistId: samplePlaylistId),
      ),
      BenchmarkScenario(
        name: 'playlist.items.provenance.page1',
        runner: () => _getPlaylistItemsByProvenance(
          playlistId: sampleProvenancePlaylistId,
          limit: 20,
          offset: 0,
        ),
      ),
      BenchmarkScenario(
        name: 'channel.preview.page1',
        runner: () => _getPlaylistItemsByChannel(
          channelId: sampleChannelId,
          limit: 25,
          offset: 0,
        ),
      ),
      BenchmarkScenario(
        name: 'works.page1',
        runner: () => _getItems(limit: 51, offset: 0),
      ),
      BenchmarkScenario(
        name: 'works.ids.page1',
        runner: () => _getItemIds(limit: 51, offset: 0),
      ),
      BenchmarkScenario(
        name: 'work.detail',
        runner: () => db.select(
          'SELECT * FROM items WHERE id = ? LIMIT 1',
          [sampleItemId],
        ),
      ),
      BenchmarkScenario(
        name: 'search.channels.suggestions',
        runner: () => db.select(
          '''
          SELECT c.*
          FROM channels_fts f
          INNER JOIN channels c ON c.id = f.id
          WHERE channels_fts MATCH ?
          ORDER BY bm25(channels_fts), c.sort_order ASC, c.id ASC
          LIMIT 4
          ''',
          [_buildFtsMatchQuery(sampleChannelTitle)],
        ),
      ),
      BenchmarkScenario(
        name: 'search.playlists.suggestions',
        runner: () => db.select(
          '''
          SELECT p.*
          FROM playlists_fts f
          INNER JOIN playlists p ON p.id = f.id
          WHERE playlists_fts MATCH ?
          ORDER BY bm25(playlists_fts), p.created_at_us DESC, p.id ASC
          LIMIT 4
          ''',
          [_buildFtsMatchQuery(samplePlaylistTitle)],
        ),
      ),
      BenchmarkScenario(
        name: 'search.items.suggestions',
        runner: () => _searchItems(query: sampleItemTitle, limit: 6),
      ),
      BenchmarkScenario(
        name: 'search.items.results',
        runner: () => _searchItems(query: sampleItemTitle, limit: 40),
      ),
    ];
  }

  void dispose() {
    db.dispose();
  }

  ResultSet _getPlaylistItemsByPosition({
    required String playlistId,
    int? limit,
    int? offset,
  }) {
    final sql = StringBuffer()
      ..writeln('SELECT i.*')
      ..writeln('FROM items i')
      ..writeln('INNER JOIN playlist_entries pe ON pe.item_id = i.id')
      ..writeln('WHERE pe.playlist_id = ?')
      ..writeln(
        'ORDER BY pe.position IS NULL ASC, pe.position ASC, pe.item_id ASC',
      );
    final params = <Object?>[playlistId];
    if (limit != null) {
      sql.writeln('LIMIT ? OFFSET ?');
      params
        ..add(limit)
        ..add(offset ?? 0);
    }
    return db.select(sql.toString(), params);
  }

  ResultSet _getPlaylistItemsByProvenance({
    required String playlistId,
    int? limit,
    int? offset,
  }) {
    final sql = StringBuffer()
      ..writeln('SELECT i.*')
      ..writeln('FROM items i')
      ..writeln('INNER JOIN playlist_entries pe ON pe.item_id = i.id')
      ..writeln('WHERE pe.playlist_id = ?')
      ..writeln('ORDER BY pe.sort_key_us DESC, pe.item_id DESC');
    final params = <Object?>[playlistId];
    if (limit != null) {
      sql.writeln('LIMIT ? OFFSET ?');
      params
        ..add(limit)
        ..add(offset ?? 0);
    }
    return db.select(sql.toString(), params);
  }

  ResultSet _getPlaylistItemsByChannel({
    required String channelId,
    int? limit,
    int? offset,
  }) {
    final sql = StringBuffer()
      ..writeln('SELECT i.*')
      ..writeln('FROM items i')
      ..writeln('INNER JOIN playlist_entries pe ON pe.item_id = i.id')
      ..writeln('INNER JOIN playlists p ON p.id = pe.playlist_id')
      ..writeln('WHERE p.channel_id = ?')
      ..writeln(
        'ORDER BY p.created_at_us ASC, p.id ASC, '
        'pe.position IS NULL ASC, pe.position ASC, pe.item_id ASC',
      );
    final params = <Object?>[channelId];
    if (limit != null) {
      sql.writeln('LIMIT ? OFFSET ?');
      params
        ..add(limit)
        ..add(offset ?? 0);
    }
    return db.select(sql.toString(), params);
  }

  List<Row> _getItems({
    required int limit,
    required int offset,
  }) {
    final ids = _getItemIds(limit: limit, offset: offset);
    if (ids.isEmpty) {
      return const [];
    }
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = db.select(
      'SELECT * FROM items WHERE id IN ($placeholders)',
      ids,
    );
    final byId = <String, Row>{
      for (final row in rows) row['id'] as String: row,
    };
    return ids.map((id) => byId[id]).whereType<Row>().toList(growable: false);
  }

  List<String> _getItemIds({
    required int limit,
    required int offset,
  }) {
    final rows = db.select(
      '''
      WITH item_rank AS (
        SELECT
          pe.item_id AS item_id,
          MIN(COALESCE(c.publisher_id, 2147483647)) AS publisher_order,
          MIN(
            COALESCE(c.created_at_us, 9223372036854775807)
          ) AS channel_created_at_order,
          MIN(
            COALESCE(p.created_at_us, 9223372036854775807)
          ) AS playlist_created_at_order
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
      LIMIT ? OFFSET ?
      ''',
      [limit, offset],
    );
    return rows.map((row) => row['id'] as String).toList(growable: false);
  }

  ResultSet _searchItems({
    required String query,
    required int limit,
  }) {
    final matchQuery = _buildFtsMatchQuery(query);
    return db.select(
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
      [matchQuery, matchQuery, limit],
    );
  }
}

String _buildFtsMatchQuery(String rawQuery) {
  final tokens = rawQuery
      .trim()
      .split(RegExp(r'\s+'))
      .map((token) => token.replaceAll(RegExp('[^A-Za-z0-9_]'), ''))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) {
    return 'art*';
  }
  return tokens.map((token) => '"$token"*').join(' ');
}
