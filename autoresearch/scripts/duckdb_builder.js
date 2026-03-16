#!/usr/bin/env node
/**
 * Builds a DuckDB database from the SQLite baseline using the DuckDB CLI.
 * Each build phase is a separate DuckDB invocation to avoid CLI input limits.
 *
 * Usage (from repo root):
 *   node autoresearch/scripts/duckdb_builder.js \
 *     --candidate <name> --output <path.duckdb> --baseline <path.sqlite>
 *
 * Candidates:
 *   duckdb_baseline     - Mirror SQLite schema; DuckDB FTS for search.
 *   duckdb_columnar     - Same schema; benchmark uses column projection.
 *   duckdb_precomputed  - Adds item_order_cache + playlists_list_cache.
 */

'use strict';

const fs = require('node:fs');
const {execFileSync} = require('node:child_process');

function main() {
  const args = parseArgs(process.argv.slice(2));
  const {candidate, output, baseline} = args;

  if (!candidate || !output || !baseline) {
    throw new Error('Usage: --candidate <name> --output <path> --baseline <sqlite>');
  }
  if (!fs.existsSync(baseline)) {
    throw new Error(`Baseline SQLite not found: ${baseline}`);
  }

  // Remove stale output so DuckDB starts fresh.
  for (const file of [output, output + '.wal']) {
    if (fs.existsSync(file)) fs.rmSync(file);
  }

  console.error(`Building candidate: ${candidate}`);
  build(candidate, output, baseline);
  console.error(`Done. Output: ${output} (${fileMb(output).toFixed(1)} MB)`);
}

function build(candidate, output, baseline) {
  // Phase 1: import tables from SQLite.
  sql(output, [
    'INSTALL sqlite; LOAD sqlite;',
    `ATTACH '${baseline}' AS src (TYPE SQLITE, READ_ONLY TRUE);`,
    'CREATE TABLE channels AS SELECT * FROM src.channels;',
    'CREATE TABLE publishers AS SELECT * FROM src.publishers;',
    'CREATE TABLE playlists AS SELECT * FROM src.playlists;',
    'CREATE TABLE items AS SELECT * FROM src.items;',
    'CREATE TABLE playlist_entries AS SELECT * FROM src.playlist_entries;',
  ]);
  console.error('  tables imported');

  // Phase 2: ART indexes for JOIN performance.
  // Each index in a separate invocation — multiple index statements in one
  // DuckDB CLI session trigger a memory corruption crash (DuckDB 1.5.0 bug).
  sql(output, ['CREATE INDEX idx_channels_pk ON channels(id);']);
  sql(output, ['CREATE INDEX idx_playlists_pk ON playlists(id);']);
  sql(output, ['CREATE INDEX idx_items_pk ON items(id);']);
  sql(output, ['CREATE INDEX idx_pe_playlist ON playlist_entries(playlist_id, item_id);']);
  sql(output, ['CREATE INDEX idx_pe_item ON playlist_entries(item_id, playlist_id);']);
  sql(output, ['CREATE INDEX idx_playlists_channel ON playlists(channel_id);']);
  console.error('  ART indexes created');

  // Phase 3: FTS indexes (separate invocations; large tables can be slow).
  sql(output, [
    'INSTALL fts; LOAD fts;',
    "PRAGMA create_fts_index('channels', 'id', 'title');",
  ]);
  sql(output, [
    'LOAD fts;',
    "PRAGMA create_fts_index('playlists', 'id', 'title');",
  ]);
  // Items FTS covers both title and list_artist_json in one index.
  sql(output, [
    'LOAD fts;',
    "PRAGMA create_fts_index('items', 'id', 'title', 'list_artist_json');",
  ]);
  console.error('  FTS indexes created');

  if (candidate === 'duckdb_precomputed') {
    // item_order_cache: precomputed sort order table (same as SQLite champion).
    sql(output, [`
CREATE TABLE item_order_cache AS
SELECT
  pe.item_id AS item_id,
  MIN(COALESCE(c.publisher_id, 2147483647)) AS publisher_order,
  MIN(COALESCE(c.created_at_us, 9223372036854775807)) AS channel_created_at_order,
  MIN(COALESCE(p.created_at_us, 9223372036854775807)) AS playlist_created_at_order
FROM playlist_entries pe
JOIN playlists p ON p.id = pe.playlist_id
LEFT JOIN channels c ON c.id = p.channel_id
GROUP BY pe.item_id;`,
      'CREATE INDEX idx_item_order ON item_order_cache(publisher_order, channel_created_at_order, playlist_created_at_order, item_id);',
    ]);

    // playlists_list_cache: slim table with publisher_order denormalized.
    sql(output, [`
CREATE TABLE playlists_list_cache AS
SELECT
  p.type,
  COALESCE(c.publisher_id, 2147483647) AS publisher_order,
  p.created_at_us,
  p.id,
  p.channel_id,
  p.slug,
  p.title,
  p.sort_mode,
  p.item_count
FROM playlists p
LEFT JOIN channels c ON c.id = p.channel_id;`,
      'CREATE INDEX idx_playlists_list_cache ON playlists_list_cache(type, publisher_order, created_at_us, id);',
    ]);
    console.error('  precomputed cache tables created');
  }

  // Final checkpoint to flush WAL into the main file.
  sql(output, ['CHECKPOINT;']);
}

function sql(dbPath, statements) {
  execFileSync('duckdb', [dbPath], {
    input: statements.join('\n'),
    stdio: ['pipe', 'ignore', 'inherit'],
    encoding: 'utf8',
  });
}

function parseArgs(argv) {
  const out = {candidate: null, output: null, baseline: null};
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i].replace(/^--/, '');
    out[key] = argv[i + 1];
  }
  return out;
}

function fileMb(p) {
  return fs.statSync(p).size / (1024 * 1024);
}

main();
