import 'package:dart_duckdb/dart_duckdb.dart';

import 'benchmark_core.dart';

class DuckDBBenchmarkBackend {
  DuckDBBenchmarkBackend({
    required this.conn,
    required this.databasePath,
  });

  final Connection conn;
  final String databasePath;

  String get backendName => 'duckdb';

  Future<List<BenchmarkScenario>> buildScenarios() async {
    final hasItemOrderCache = await _tableExists('item_order_cache');
    final hasPlaylistListCache = await _tableExists('playlists_list_cache');

    // Seed sample values for parametric scenarios.
    final channelRows = (await conn.query(
      '''
      SELECT id, title
      FROM channels
      WHERE type = 0
      ORDER BY COALESCE(publisher_id, 2147483647) ASC,
               COALESCE(sort_order, 2147483647) ASC, id ASC
      LIMIT 20
      ''',
    )).fetchAll();

    final playlistRows = (await conn.query(
      hasPlaylistListCache
          ? '''
            SELECT id, title, sort_mode
            FROM playlists_list_cache
            WHERE type = 0
            ORDER BY publisher_order ASC, created_at_us ASC
            '''
          : '''
            SELECT id, title, sort_mode
            FROM playlists
            WHERE type = 0
            ORDER BY COALESCE(
              (SELECT publisher_id FROM channels c WHERE c.id = playlists.channel_id),
              2147483647
            ) ASC, created_at_us ASC
            ''',
    )).fetchAll();

    final workRows = await _getItemIdRows(
      limit: 100,
      offset: 0,
      hasItemOrderCache: hasItemOrderCache,
    );

    if (channelRows.isEmpty || playlistRows.isEmpty || workRows.isEmpty) {
      throw StateError(
        'Benchmark requires non-empty channels, playlists, and works. '
        'channels=${channelRows.length}, playlists=${playlistRows.length}, '
        'works=${workRows.length}',
      );
    }

    final positionPlaylist = playlistRows.firstWhere(
      (row) => row[2] == 0,
      orElse: () => playlistRows.first,
    );
    final provenancePlaylist = playlistRows.firstWhere(
      (row) => row[2] == 1,
      orElse: () => positionPlaylist,
    );

    final sampleChannelId = channelRows.first[0] as String;
    final sampleChannelTitle = channelRows.first[1] as String? ?? '';
    final samplePlaylistId = positionPlaylist[0] as String;
    final samplePlaylistTitle = positionPlaylist[1] as String? ?? '';
    final sampleProvenancePlaylistId = provenancePlaylist[0] as String;
    final sampleItemId = workRows.first[0] as String;

    // Seed a sample item title for FTS from first 100 works.
    final itemTitleRow = (await conn.query(
      "SELECT title FROM items WHERE id = '${sampleItemId.replaceAll("'", "''")}' LIMIT 1",
    )).fetchAll();
    final sampleItemTitle = itemTitleRow.isNotEmpty
        ? (itemTitleRow.first[0] as String? ?? '')
        : '';

    return [
      BenchmarkScenario(
        name: 'channels.dp1.page1.limit11',
        runner: () => conn.query(
          '''
          SELECT *
          FROM channels
          WHERE type = 0
          ORDER BY COALESCE(publisher_id, 2147483647) ASC,
                   (sort_order IS NULL)::INTEGER ASC,
                   COALESCE(sort_order, 2147483647) ASC,
                   id ASC
          LIMIT 11
          ''',
        ),
      ),
      BenchmarkScenario(
        name: 'channels.dp1.page2.limit10',
        runner: () => conn.query(
          '''
          SELECT *
          FROM channels
          WHERE type = 0
          ORDER BY COALESCE(publisher_id, 2147483647) ASC,
                   (sort_order IS NULL)::INTEGER ASC,
                   COALESCE(sort_order, 2147483647) ASC,
                   id ASC
          LIMIT 10 OFFSET 10
          ''',
        ),
      ),
      BenchmarkScenario(
        name: 'playlists.dp1.all',
        runner: hasPlaylistListCache
            ? () => conn.query(
                  '''
                  SELECT *
                  FROM playlists_list_cache
                  WHERE type = 0
                  ORDER BY publisher_order ASC, created_at_us ASC
                  ''',
                )
            : () => conn.query(
                  '''
                  SELECT p.*
                  FROM playlists p
                  LEFT JOIN channels c ON c.id = p.channel_id
                  WHERE p.type = 0
                  ORDER BY COALESCE(c.publisher_id, 2147483647) ASC,
                           p.created_at_us ASC
                  ''',
                ),
      ),
      BenchmarkScenario(
        name: 'channel.detail',
        runner: () => conn.query(
          "SELECT * FROM channels WHERE id = '$sampleChannelId' LIMIT 1",
        ),
      ),
      BenchmarkScenario(
        name: 'playlist.detail',
        runner: () => conn.query(
          "SELECT * FROM playlists WHERE id = '$samplePlaylistId' LIMIT 1",
        ),
      ),
      BenchmarkScenario(
        name: 'playlist.items.position.page1',
        runner: () => conn.query(
          '''
          SELECT i.*
          FROM items i
          INNER JOIN playlist_entries pe ON pe.item_id = i.id
          WHERE pe.playlist_id = '$samplePlaylistId'
          ORDER BY (pe.position IS NULL)::INTEGER ASC, pe.position ASC, pe.item_id ASC
          LIMIT 20 OFFSET 0
          ''',
        ),
      ),
      BenchmarkScenario(
        name: 'playlist.items.position.full',
        runner: () => conn.query(
          '''
          SELECT i.*
          FROM items i
          INNER JOIN playlist_entries pe ON pe.item_id = i.id
          WHERE pe.playlist_id = '$samplePlaylistId'
          ORDER BY (pe.position IS NULL)::INTEGER ASC, pe.position ASC, pe.item_id ASC
          ''',
        ),
      ),
      BenchmarkScenario(
        name: 'playlist.items.provenance.page1',
        runner: () => conn.query(
          '''
          SELECT i.*
          FROM items i
          INNER JOIN playlist_entries pe ON pe.item_id = i.id
          WHERE pe.playlist_id = '$sampleProvenancePlaylistId'
          ORDER BY pe.sort_key_us DESC, pe.item_id DESC
          LIMIT 20 OFFSET 0
          ''',
        ),
      ),
      BenchmarkScenario(
        name: 'channel.preview.page1',
        runner: () => conn.query(
          '''
          SELECT i.*
          FROM items i
          INNER JOIN playlist_entries pe ON pe.item_id = i.id
          INNER JOIN playlists p ON p.id = pe.playlist_id
          WHERE p.channel_id = '$sampleChannelId'
          ORDER BY p.created_at_us ASC, p.id ASC,
                   (pe.position IS NULL)::INTEGER ASC,
                   pe.position ASC, pe.item_id ASC
          LIMIT 25 OFFSET 0
          ''',
        ),
      ),
      BenchmarkScenario(
        name: 'works.page1',
        runner: () => _getItems(
          limit: 51,
          offset: 0,
          hasItemOrderCache: hasItemOrderCache,
        ),
      ),
      BenchmarkScenario(
        name: 'works.ids.page1',
        runner: () => _getItemIdRows(
          limit: 51,
          offset: 0,
          hasItemOrderCache: hasItemOrderCache,
        ),
      ),
      BenchmarkScenario(
        name: 'work.detail',
        runner: () => conn.query(
          "SELECT * FROM items WHERE id = '$sampleItemId' LIMIT 1",
        ),
      ),
      BenchmarkScenario(
        name: 'search.channels.suggestions',
        runner: () => _searchFts(
          table: 'channels',
          query: _buildFtsQuery(sampleChannelTitle),
          limit: 4,
        ),
      ),
      BenchmarkScenario(
        name: 'search.playlists.suggestions',
        runner: () => _searchFts(
          table: 'playlists',
          query: _buildFtsQuery(samplePlaylistTitle),
          limit: 4,
        ),
      ),
      BenchmarkScenario(
        name: 'search.items.suggestions',
        runner: () => _searchFts(
          table: 'items',
          query: _buildFtsQuery(sampleItemTitle),
          limit: 6,
        ),
      ),
      BenchmarkScenario(
        name: 'search.items.results',
        runner: () => _searchFts(
          table: 'items',
          query: _buildFtsQuery(sampleItemTitle),
          limit: 40,
        ),
      ),
    ];
  }

  Future<void> dispose() async {
    await conn.dispose();
  }

  Future<bool> _tableExists(String tableName) async {
    final result = await conn.query(
      "SELECT COUNT(*) FROM information_schema.tables "
      "WHERE table_name = '$tableName'",
    );
    final rows = result.fetchAll();
    return (rows.first[0] as int) > 0;
  }

  Future<List<List<Object?>>> _getItems({
    required int limit,
    required int offset,
    required bool hasItemOrderCache,
  }) async {
    final idRows = await _getItemIdRows(
      limit: limit,
      offset: offset,
      hasItemOrderCache: hasItemOrderCache,
    );
    if (idRows.isEmpty) return const [];
    final ids = idRows.map((r) => "'${(r[0] as String).replaceAll("'", "''")}'").join(',');
    // Select only list-view columns — DuckDB reads only the needed column
    // vectors, skipping token_data_json entirely.
    final result = await conn.query(
      '''
      SELECT id, kind, title, subtitle, thumbnail_uri, duration_sec,
             provenance_json, source_uri, ref_uri, license,
             list_artist_json, enrichment_status, updated_at_us
      FROM items
      WHERE id IN ($ids)
      ''',
    );
    return result.fetchAll();
  }

  Future<List<List<Object?>>> _getItemIdRows({
    required int limit,
    required int offset,
    required bool hasItemOrderCache,
  }) async {
    if (hasItemOrderCache) {
      final result = await conn.query(
        '''
        SELECT item_id AS id
        FROM item_order_cache
        ORDER BY publisher_order ASC, channel_created_at_order ASC,
                 playlist_created_at_order ASC, item_id ASC
        LIMIT $limit OFFSET $offset
        ''',
      );
      return result.fetchAll();
    }

    final result = await conn.query(
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
      ORDER BY COALESCE(r.publisher_order, 2147483647) ASC,
               COALESCE(r.channel_created_at_order, 9223372036854775807) ASC,
               COALESCE(r.playlist_created_at_order, 9223372036854775807) ASC,
               i.id ASC
      LIMIT $limit OFFSET $offset
      ''',
    );
    return result.fetchAll();
  }

  Future<ResultSet> _searchFts({
    required String table,
    required String query,
    required int limit,
  }) {
    // DuckDB FTS: match_bm25 must appear in both WHERE and SELECT to resolve.
    // Returns NULL for non-matching rows, so we filter them out.
    // Lower score = better match (same sign convention as SQLite's bm25()).
    return conn.query(
      '''
      SELECT id, fts_main_$table.match_bm25(id, '$query') AS _score
      FROM $table
      WHERE fts_main_$table.match_bm25(id, '$query') IS NOT NULL
      ORDER BY _score ASC
      LIMIT $limit
      ''',
    );
  }
}

/// Converts raw query text into a DuckDB FTS match query.
/// Uses the same token-splitting logic as the SQLite backend but without
/// the SQLite `*` prefix operator (DuckDB FTS uses plain-word queries).
String _buildFtsQuery(String rawQuery) {
  final tokens = rawQuery
      .trim()
      .split(RegExp(r'\s+'))
      .map((token) => token.replaceAll(RegExp('[^A-Za-z0-9_]'), ''))
      .where((token) => token.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) {
    return 'art';
  }
  return tokens.join(' ');
}
