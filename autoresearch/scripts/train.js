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
