#!/usr/bin/env node

/* eslint-disable no-console */
const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

function parseArgs(argv) {
  const out = {
    db: path.resolve(__dirname, 'ff_feed_indexer_seed.sqlite'),
    channelId: '',
    reportPath: path.resolve(process.cwd(), 'casey-canary-report.json'),
    minPlaylists: 1,
    minItems: 1,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = argv[i + 1];
    switch (arg) {
      case '--db':
        out.db = path.resolve(next);
        i += 1;
        break;
      case '--channel-id':
        out.channelId = String(next || '').trim();
        i += 1;
        break;
      case '--report':
        out.reportPath = path.resolve(next);
        i += 1;
        break;
      case '--min-playlists':
        out.minPlaylists = Number(next);
        i += 1;
        break;
      case '--min-items':
        out.minItems = Number(next);
        i += 1;
        break;
      default:
        if (arg.startsWith('-')) {
          throw new Error(`Unknown argument: ${arg}`);
        }
    }
  }

  if (!out.channelId) {
    throw new Error('Missing --channel-id');
  }
  if (!Number.isFinite(out.minPlaylists) || out.minPlaylists <= 0) {
    throw new Error('--min-playlists must be > 0');
  }
  if (!Number.isFinite(out.minItems) || out.minItems <= 0) {
    throw new Error('--min-items must be > 0');
  }

  return out;
}

function sqliteQuery(dbPath, sql) {
  return execFileSync('sqlite3', [dbPath, '-json', sql], {
    encoding: 'utf-8',
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(args.db)) {
    throw new Error(`Seed DB not found: ${args.db}`);
  }

  const channelRows = JSON.parse(
    sqliteQuery(
      args.db,
      `SELECT id, title, publisher_id FROM channels WHERE id='${args.channelId.replace(/'/gu, "''")}';`
    ) || '[]'
  );

  if (!Array.isArray(channelRows) || channelRows.length === 0) {
    throw new Error(`Channel not found in seed DB: ${args.channelId}`);
  }

  const counts = JSON.parse(
    sqliteQuery(
      args.db,
      `SELECT COUNT(DISTINCT p.id) AS playlists, COUNT(i.id) AS items FROM playlists p LEFT JOIN playlist_entries pe ON pe.playlist_id=p.id LEFT JOIN items i ON i.id=pe.item_id WHERE p.channel_id='${args.channelId.replace(/'/gu, "''")}';`
    ) || '[]'
  )[0] || {playlists: 0, items: 0};

  if (Number(counts.playlists) < args.minPlaylists) {
    throw new Error(
      `Channel ${args.channelId} has ${counts.playlists} playlists, requires >= ${args.minPlaylists}`
    );
  }
  if (Number(counts.items) < args.minItems) {
    throw new Error(
      `Channel ${args.channelId} has ${counts.items} items, requires >= ${args.minItems}`
    );
  }

  const report = {
    generated_at: new Date().toISOString(),
    seed_db: args.db,
    channel: channelRows[0],
    metrics: {
      playlists: Number(counts.playlists),
      items: Number(counts.items),
      min_playlists: args.minPlaylists,
      min_items: args.minItems,
    },
    soak_protocol: {
      duration_hours_min: 4,
      canonical_play_path: 'json_to_ff1',
      pass_condition: 'continuous playback >= 4h with no fatal interruption',
      required_evidence: [
        'app cast success log',
        'relayer cast ack',
        'ff1 player status continuity',
      ],
    },
  };

  fs.writeFileSync(args.reportPath, JSON.stringify(report, null, 2), 'utf-8');
  console.log(`[ok] Casey canary preflight report: ${args.reportPath}`);
}

try {
  main();
} catch (error) {
  console.error(`[error] ${error?.message || String(error)}`);
  process.exit(1);
}
