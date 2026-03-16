#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

const rootDir = path.resolve(__dirname, '..');
const dataDir = path.join(rootDir, 'data');
const baselineDir = path.join(dataDir, 'baseline');
const candidatesDir = path.join(dataDir, 'candidates');
const runLogsDir = path.join(rootDir, 'run-logs');
const resultsPath = path.join(rootDir, 'results.tsv');
const summaryPath = path.join(rootDir, 'last_run_summary.json');
const manifestPath = path.join(dataDir, 'manifest.json');
const baselinePath = path.join(baselineDir, 'baseline.sqlite');
const benchmarkScript = path.join('autoresearch', 'scripts', 'query_benchmark.dart');
const RESULTS_HEADER =
  'candidate\tbackend\tdb_size_mb\tsize_delta_mb\tavg_p95_ms\tmax_p95_ms\tlatency_score\tstatus\tnotes\n';

main().catch((error) => {
  console.error(error?.stack || String(error));
  process.exit(1);
});

async function main() {
  ensurePrepared();

  const args = parseArgs(process.argv.slice(2));
  const baselineSizeBytes = fs.statSync(baselinePath).size;
  const candidates = buildCandidates().filter((candidate) => {
    return !args.candidate || candidate.name === args.candidate;
  });

  if (candidates.length === 0) {
    throw new Error(`No candidates matched --candidate=${args.candidate}`);
  }

  const results = [];
  for (const candidate of candidates) {
    const artifact = materializeCandidate(candidate);

    const metricsPath = path.join(runLogsDir, `${candidate.name}.metrics.json`);
    const logPath = path.join(runLogsDir, `${candidate.name}.log`);
    const rawOutput = execFileSync(
      'dart',
      [
        'run',
        benchmarkScript,
        '--backend',
        artifact.backend,
        '--database',
        artifact.databasePath,
        '--label',
        candidate.name,
        '--output',
        metricsPath,
      ],
      {
        cwd: path.resolve(rootDir, '..'),
        encoding: 'utf8',
      },
    );
    fs.writeFileSync(logPath, rawOutput);

    const metrics = JSON.parse(fs.readFileSync(metricsPath, 'utf8'));
    const dbSizeBytes = fs.statSync(artifact.databasePath).size;
    const avgP95Ms = round3(metrics.avgP95Ms);
    const maxP95Ms = round3(metrics.maxP95Ms);
    const latencyScore = round3(maxP95Ms * 1000 + avgP95Ms);

    const row = {
      candidate: candidate.name,
      backend: artifact.backend,
      dbSizeMb: round3(bytesToMb(dbSizeBytes)),
      sizeDeltaMb: round3(bytesToMb(dbSizeBytes - baselineSizeBytes)),
      avgP95Ms,
      maxP95Ms,
      latencyScore,
      status: 'pending',
      notes: candidate.notes,
      metrics,
      dbPath: artifact.databasePath,
    };
    results.push(row);
  }

  const rankedResults = rankResults(results);
  fs.writeFileSync(resultsPath, RESULTS_HEADER);
  for (const result of rankedResults) {
    appendResult(result);
  }

  fs.writeFileSync(
    summaryPath,
    `${JSON.stringify({generatedAt: new Date().toISOString(), results: rankedResults}, null, 2)}\n`,
  );
  for (const result of rankedResults) {
    console.log(
      [
        `${result.candidate}:`,
        `backend=${result.backend}`,
        `size=${result.dbSizeMb}MB`,
        `delta=${result.sizeDeltaMb}MB`,
        `avg_p95=${result.avgP95Ms}ms`,
        `max_p95=${result.maxP95Ms}ms`,
        `latency_score=${result.latencyScore}`,
        `status=${result.status}`,
      ].join(' '),
    );
  }
}

function ensurePrepared() {
  if (!fs.existsSync(manifestPath) || !fs.existsSync(baselinePath)) {
    throw new Error('Prepare step is missing. Run `node autoresearch/scripts/prepare.js` first.');
  }
  fs.mkdirSync(candidatesDir, {recursive: true});
  fs.mkdirSync(runLogsDir, {recursive: true});
  if (!fs.existsSync(resultsPath)) {
    fs.writeFileSync(resultsPath, RESULTS_HEADER);
  }
}

function parseArgs(argv) {
  const out = {candidate: undefined};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = argv[index + 1];
    if (arg === '--candidate') {
      out.candidate = next;
      index += 1;
      continue;
    }
    if (arg.startsWith('-')) {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return out;
}

function buildItemOrderCacheStatements() {
  return [
    `CREATE TABLE item_order_cache (
      item_id TEXT PRIMARY KEY,
      publisher_order INTEGER NOT NULL,
      channel_created_at_order INTEGER NOT NULL,
      playlist_created_at_order INTEGER NOT NULL
    ) WITHOUT ROWID;`,
    `INSERT INTO item_order_cache
      SELECT
        pe.item_id,
        MIN(COALESCE(c.publisher_id, 2147483647)),
        MIN(COALESCE(c.created_at_us, 9223372036854775807)),
        MIN(COALESCE(p.created_at_us, 9223372036854775807))
      FROM playlist_entries pe
      JOIN playlists p ON p.id = pe.playlist_id
      LEFT JOIN channels c ON c.id = p.channel_id
      GROUP BY pe.item_id;`,
    `CREATE INDEX idx_item_order_cache_lookup
      ON item_order_cache(
        publisher_order,
        channel_created_at_order,
        playlist_created_at_order,
        item_id
      );`,
  ];
}

function buildPlaylistsPubDenormStatements() {
  return [
    'ALTER TABLE playlists ADD COLUMN publisher_order INTEGER NOT NULL DEFAULT 2147483647;',
    'UPDATE playlists SET publisher_order = COALESCE((SELECT publisher_id FROM channels WHERE id = playlists.channel_id), 2147483647);',
    'CREATE INDEX idx_playlists_type_puborder_created ON playlists(type, publisher_order ASC, created_at_us ASC, id ASC);',
  ];
}

// A compact rowid table for items with only list-view columns, inserted in
// item_order_cache rank order so first-page items are physically co-located.
// Excludes token_data_json (avg 7.2KB), repro_json, override_json, display_json.
// Must be built AFTER item_order_cache is populated.
function buildItemsHeadStatements() {
  return [
    `CREATE TABLE items_head (
      id TEXT NOT NULL PRIMARY KEY,
      kind TEXT NOT NULL,
      title TEXT,
      subtitle TEXT,
      thumbnail_uri TEXT,
      duration_sec INTEGER,
      provenance_json TEXT,
      source_uri TEXT,
      ref_uri TEXT,
      license TEXT,
      list_artist_json TEXT,
      enrichment_status INTEGER,
      updated_at_us INTEGER NOT NULL
    );`,

    // Insert in item_order_cache rank order so first-page items land on
    // contiguous pages, improving locality for IN-list page-one fetches.
    `INSERT INTO items_head
      SELECT i.id, i.kind, i.title, i.subtitle, i.thumbnail_uri,
             i.duration_sec, i.provenance_json, i.source_uri, i.ref_uri,
             i.license, i.list_artist_json, i.enrichment_status, i.updated_at_us
      FROM item_order_cache c
      JOIN items i ON i.id = c.item_id
      ORDER BY c.publisher_order, c.channel_created_at_order,
               c.playlist_created_at_order, c.item_id;`,
  ];
}

// A compact WITHOUT ROWID precomputed list-cache for playlists containing
// only the columns needed for the list-view query, clustered by sort order.
// Removes signatures_json, defaults_json, dynamic_queries_json, base_url,
// dp_version, owner_address, owner_chain, updated_at_us — not needed for list.
function buildPlaylistsListCacheStatements() {
  return [
    `CREATE TABLE playlists_list_cache (
      type INTEGER NOT NULL,
      publisher_order INTEGER NOT NULL DEFAULT 2147483647,
      created_at_us INTEGER NOT NULL,
      id TEXT NOT NULL,
      channel_id TEXT,
      slug TEXT,
      title TEXT NOT NULL,
      sort_mode INTEGER NOT NULL,
      item_count INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (type, publisher_order, created_at_us, id)
    ) WITHOUT ROWID;`,

    `INSERT INTO playlists_list_cache
      SELECT
        p.type,
        COALESCE(c.publisher_id, 2147483647),
        p.created_at_us,
        p.id, p.channel_id, p.slug, p.title, p.sort_mode, p.item_count
      FROM playlists p
      LEFT JOIN channels c ON c.id = p.channel_id;`,
  ];
}

// Converts the playlists table to a WITHOUT ROWID table clustered by the
// primary list-query sort key (type, publisher_order, created_at_us, id).
// This turns the playlists.dp1.all scan into a sequential B-tree traversal
// instead of a secondary-index + random-rowid-lookup pattern.
function buildPlaylistsClusteredStatements() {
  return [
    `CREATE TABLE playlists_new (
      type INTEGER NOT NULL,
      publisher_order INTEGER NOT NULL DEFAULT 2147483647,
      created_at_us INTEGER NOT NULL,
      id TEXT NOT NULL,
      channel_id TEXT,
      base_url TEXT,
      dp_version TEXT,
      slug TEXT,
      title TEXT NOT NULL,
      updated_at_us INTEGER NOT NULL,
      signatures_json TEXT NOT NULL,
      defaults_json TEXT,
      dynamic_queries_json TEXT,
      owner_address TEXT,
      owner_chain TEXT,
      sort_mode INTEGER NOT NULL,
      item_count INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (type, publisher_order, created_at_us, id)
    ) WITHOUT ROWID;`,

    `INSERT INTO playlists_new
      SELECT
        p.type,
        COALESCE(c.publisher_id, 2147483647),
        p.created_at_us,
        p.id, p.channel_id, p.base_url, p.dp_version, p.slug, p.title,
        p.updated_at_us, p.signatures_json, p.defaults_json,
        p.dynamic_queries_json, p.owner_address, p.owner_chain,
        p.sort_mode, p.item_count
      FROM playlists p
      LEFT JOIN channels c ON c.id = p.channel_id;`,

    // Secondary index for id-based lookups (playlist.detail, JOIN from playlist_entries).
    'CREATE UNIQUE INDEX idx_playlists_id ON playlists_new(id);',

    'DROP TRIGGER IF EXISTS playlists_ai;',
    'DROP TRIGGER IF EXISTS playlists_ad;',
    'DROP TRIGGER IF EXISTS playlists_au;',

    'DROP TABLE playlists;',
    'ALTER TABLE playlists_new RENAME TO playlists;',

    `CREATE TRIGGER playlists_ai AFTER INSERT ON playlists BEGIN
      INSERT INTO playlists_fts(id, title) VALUES (new.id, new.title);
    END;`,
    `CREATE TRIGGER playlists_ad AFTER DELETE ON playlists BEGIN
      DELETE FROM playlists_fts WHERE id = old.id;
    END;`,
    `CREATE TRIGGER playlists_au AFTER UPDATE ON playlists BEGIN
      DELETE FROM playlists_fts WHERE id = old.id;
      INSERT INTO playlists_fts(id, title) VALUES (new.id, new.title);
    END;`,
  ];
}

function buildCandidates() {
  return [
    {
      name: 'baseline',
      backend: 'sqlite',
      notes: 'Exact baseline copied from the repo feed/indexer SQLite builder.',
      mutate() {},
    },
    {
      name: 'vacuum_optimize',
      backend: 'sqlite',
      notes: 'Repack baseline with VACUUM and PRAGMA optimize to trim fragmentation and refresh planner stats.',
      mutate(dbPath) {
        runSql(dbPath, [
          'PRAGMA optimize;',
          "INSERT INTO channels_fts(channels_fts) VALUES('optimize');",
          "INSERT INTO playlists_fts(playlists_fts) VALUES('optimize');",
          "INSERT INTO items_fts(items_fts) VALUES('optimize');",
          "INSERT INTO item_artists_fts(item_artists_fts) VALUES('optimize');",
          'VACUUM;',
          'ANALYZE;',
        ]);
      },
    },
    {
      name: 'page8k_optimize',
      backend: 'sqlite',
      notes: 'Use 8KB pages plus VACUUM/ANALYZE to test a denser page layout for this dataset.',
      mutate(dbPath) {
        runSql(dbPath, [
          'PRAGMA page_size = 8192;',
          'VACUUM;',
          'ANALYZE;',
          'PRAGMA optimize;',
        ]);
      },
    },
    {
      name: 'page16k_optimize',
      backend: 'sqlite',
      notes: 'Use 16KB pages plus VACUUM/ANALYZE to test larger pages for read-heavy scans and FTS.',
      mutate(dbPath) {
        runSql(dbPath, [
          'PRAGMA page_size = 16384;',
          'VACUUM;',
          'ANALYZE;',
          'PRAGMA optimize;',
        ]);
      },
    },
    {
      name: 'covering_indexes',
      backend: 'sqlite',
      notes: 'Add covering indexes for hot ordered list queries, then ANALYZE and optimize FTS.',
      mutate(dbPath) {
        runSql(dbPath, [
          'CREATE INDEX IF NOT EXISTS idx_channels_type_sort_id ON channels(type, sort_order, id);',
          'CREATE INDEX IF NOT EXISTS idx_playlists_type_created_id ON playlists(type, created_at_us, id);',
          'CREATE INDEX IF NOT EXISTS idx_playlists_channel_created_id ON playlists(channel_id, created_at_us, id);',
          'CREATE INDEX IF NOT EXISTS idx_items_updated_id ON items(updated_at_us DESC, id ASC);',
          'ANALYZE;',
          'PRAGMA optimize;',
          "INSERT INTO channels_fts(channels_fts) VALUES('optimize');",
          "INSERT INTO playlists_fts(playlists_fts) VALUES('optimize');",
          "INSERT INTO items_fts(items_fts) VALUES('optimize');",
          "INSERT INTO item_artists_fts(item_artists_fts) VALUES('optimize');",
        ]);
      },
    },
    {
      name: 'item_order_cache',
      backend: 'sqlite',
      notes:
        'Materialize works ordering into a compact WITHOUT ROWID cache table with a covering sort index. '
        + 'Benchmark uses the cache for _getItemIds, eliminating the GROUP BY CTE over playlist_entries.',
      mutate(dbPath) {
        runSql(dbPath, [
          ...buildItemOrderCacheStatements(),
          'ANALYZE;',
        ]);
      },
    },
    {
      name: 'playlists_pub_denorm',
      backend: 'sqlite',
      notes:
        'Denormalize publisher_order into the playlists table to eliminate the channels JOIN in playlists.dp1.all. '
        + 'Benchmark uses the new column with a covering index on (type, publisher_order, created_at_us, id).',
      mutate(dbPath) {
        runSql(dbPath, [
          ...buildPlaylistsPubDenormStatements(),
          'ANALYZE;',
          'PRAGMA optimize;',
        ]);
      },
    },
    {
      name: 'full_order_caches',
      backend: 'sqlite',
      notes:
        'Combine item_order_cache and playlists publisher_order denormalization, then VACUUM. '
        + 'Targets both remaining hotspots: playlists.dp1.all JOIN and works.ids CTE.',
      mutate(dbPath) {
        runSql(dbPath, [
          ...buildItemOrderCacheStatements(),
          ...buildPlaylistsPubDenormStatements(),
          'ANALYZE;',
          'PRAGMA optimize;',
          'VACUUM;',
        ]);
      },
    },
    {
      name: 'schema_compact',
      backend: 'sqlite',
      notes:
        'Drop 100%-null columns (repro_json, override_json) from items plus VACUUM. '
        + 'Reduces row size to improve IN-list item fetch throughput.',
      mutate(dbPath) {
        runSql(dbPath, [
          'ALTER TABLE items DROP COLUMN repro_json;',
          'ALTER TABLE items DROP COLUMN override_json;',
          'VACUUM;',
          'ANALYZE;',
        ]);
      },
    },
    {
      name: 'full_optimized',
      backend: 'sqlite',
      notes:
        'All optimizations combined: item_order_cache + playlists publisher_order denorm + drop null columns + VACUUM.',
      mutate(dbPath) {
        runSql(dbPath, [
          ...buildItemOrderCacheStatements(),
          ...buildPlaylistsPubDenormStatements(),
          'ALTER TABLE items DROP COLUMN repro_json;',
          'ALTER TABLE items DROP COLUMN override_json;',
          'ANALYZE;',
          'PRAGMA optimize;',
          'VACUUM;',
        ]);
      },
    },
    {
      name: 'full_optimized_page16k',
      backend: 'sqlite',
      notes:
        'full_optimized plus 16KB page size. Larger pages reduce random I/O for the playlists.dp1.all sequential scan, '
        + 'now that the works CTE bottleneck is eliminated.',
      mutate(dbPath) {
        runSql(dbPath, [
          ...buildItemOrderCacheStatements(),
          ...buildPlaylistsPubDenormStatements(),
          'ALTER TABLE items DROP COLUMN repro_json;',
          'ALTER TABLE items DROP COLUMN override_json;',
          'ANALYZE;',
          'PRAGMA optimize;',
          'PRAGMA page_size = 16384;',
          'VACUUM;',
        ]);
      },
    },
    {
      name: 'playlists_clustered',
      backend: 'sqlite',
      notes:
        'Convert playlists to a WITHOUT ROWID table clustered by (type, publisher_order, created_at_us, id). '
        + 'Turns playlists.dp1.all into a sequential B-tree traversal with no secondary rowid lookups. '
        + 'Combined with item_order_cache and schema_compact.',
      mutate(dbPath) {
        runSql(dbPath, [
          ...buildItemOrderCacheStatements(),
          ...buildPlaylistsClusteredStatements(),
          'ALTER TABLE items DROP COLUMN repro_json;',
          'ALTER TABLE items DROP COLUMN override_json;',
          'ANALYZE;',
          'PRAGMA optimize;',
          'VACUUM;',
        ]);
      },
    },
    {
      name: 'playlists_clustered_page16k',
      backend: 'sqlite',
      notes:
        'playlists_clustered plus 16KB pages. The sequential clustered scan for 152KB of playlists data '
        + 'reads ~10 pages at 16KB vs ~38 pages at 4KB, reducing I/O for playlists.dp1.all.',
      mutate(dbPath) {
        runSql(dbPath, [
          ...buildItemOrderCacheStatements(),
          ...buildPlaylistsClusteredStatements(),
          'ALTER TABLE items DROP COLUMN repro_json;',
          'ALTER TABLE items DROP COLUMN override_json;',
          'PRAGMA page_size = 16384;',
          'ANALYZE;',
          'PRAGMA optimize;',
          'VACUUM;',
        ]);
      },
    },
    {
      name: 'playlists_list_cache',
      backend: 'sqlite',
      notes:
        'Precompute a compact playlists_list_cache WITHOUT ROWID table (~124 bytes/row vs ~312 bytes) '
        + 'with only list-view columns, clustered by sort order. Combined with item_order_cache.',
      mutate(dbPath) {
        runSql(dbPath, [
          ...buildItemOrderCacheStatements(),
          ...buildPlaylistsListCacheStatements(),
          'ALTER TABLE items DROP COLUMN repro_json;',
          'ALTER TABLE items DROP COLUMN override_json;',
          'ANALYZE;',
          'PRAGMA optimize;',
          'VACUUM;',
        ]);
      },
    },
    {
      name: 'items_head_split',
      backend: 'sqlite',
      notes:
        'items_head rowid table ordered by access rank + playlists_list_cache. '
        + 'Works.page1 fetches from items_head (~304 bytes/row), playlists.dp1.all uses compact list cache.',
      mutate(dbPath) {
        runSql(dbPath, [
          ...buildItemOrderCacheStatements(),
          ...buildPlaylistsListCacheStatements(),
          ...buildItemsHeadStatements(),
          'ANALYZE;',
          'PRAGMA optimize;',
          'VACUUM;',
        ]);
      },
    },
    {
      name: 'items_head_clustered_playlists',
      backend: 'sqlite',
      notes:
        'items_head (ordered by access rank) + playlists_clustered (WITHOUT ROWID, full columns). '
        + 'Tests if clustered playlists outperforms the slim list cache for playlists.dp1.all.',
      mutate(dbPath) {
        runSql(dbPath, [
          ...buildItemOrderCacheStatements(),
          ...buildPlaylistsClusteredStatements(),
          ...buildItemsHeadStatements(),
          'ALTER TABLE items DROP COLUMN repro_json;',
          'ALTER TABLE items DROP COLUMN override_json;',
          'ANALYZE;',
          'PRAGMA optimize;',
          'VACUUM;',
        ]);
      },
    },
    {
      name: 'all_caches',
      backend: 'sqlite',
      notes:
        'items_head (ordered) + playlists_list_cache + item_order_cache + drop 100%-null item columns + VACUUM. '
        + 'Combines all validated optimizations into a single candidate.',
      mutate(dbPath) {
        runSql(dbPath, [
          ...buildItemOrderCacheStatements(),
          ...buildPlaylistsListCacheStatements(),
          ...buildItemsHeadStatements(),
          'ALTER TABLE items DROP COLUMN repro_json;',
          'ALTER TABLE items DROP COLUMN override_json;',
          'ANALYZE;',
          'PRAGMA optimize;',
          'VACUUM;',
        ]);
      },
    },
  ];
}

function materializeCandidate(candidate) {
  switch (candidate.backend) {
    case 'sqlite': {
      const dbPath = path.join(candidatesDir, `${candidate.name}.sqlite`);
      fs.copyFileSync(baselinePath, dbPath);
      candidate.mutate(dbPath);
      return {
        backend: 'sqlite',
        databasePath: dbPath,
      };
    }
    default:
      throw new Error(
        `Unsupported candidate backend "${candidate.backend}". `
          + 'Add a materializer in train.js and a matching Dart backend adapter.',
      );
  }
}

function runSql(dbPath, statements) {
  const sql = `${statements.join('\n')}\n`;
  execFileSync('sqlite3', [dbPath], {
    input: sql,
    stdio: ['pipe', 'ignore', 'inherit'],
  });
}

function appendResult(row) {
  const line = [
    row.candidate,
    row.backend,
    row.dbSizeMb.toFixed(3),
    row.sizeDeltaMb.toFixed(3),
    row.avgP95Ms.toFixed(3),
    row.maxP95Ms.toFixed(3),
    row.latencyScore.toFixed(3),
    row.status,
    row.notes.replaceAll('\t', ' '),
  ].join('\t');
  fs.appendFileSync(resultsPath, `${line}\n`);
}

function rankResults(results) {
  const sorted = [...results].sort((left, right) => {
    if (left.maxP95Ms !== right.maxP95Ms) {
      return left.maxP95Ms - right.maxP95Ms;
    }
    if (left.avgP95Ms !== right.avgP95Ms) {
      return left.avgP95Ms - right.avgP95Ms;
    }
    return left.dbSizeMb - right.dbSizeMb;
  });

  const best = sorted[0];
  return sorted.map((result, index) => {
    if (index === 0) {
      return {
        ...result,
        status: 'keep',
      };
    }

    const latencyGap = result.maxP95Ms - best.maxP95Ms;
    const sizeGap = result.dbSizeMb - best.dbSizeMb;
    if (latencyGap < 0.25 && sizeGap <= 1.0) {
      return {
        ...result,
        status: 'investigate',
      };
    }

    return {
      ...result,
      status: 'discard',
    };
  });
}

function bytesToMb(bytes) {
  return bytes / (1024 * 1024);
}

function round3(value) {
  return Math.round(value * 1000) / 1000;
}
