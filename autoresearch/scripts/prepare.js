#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const https = require('node:https');

const repoRoot = path.resolve(__dirname, '..', '..');
const rootDir = path.resolve(__dirname, '..');
const dataDir = path.join(rootDir, 'data');
const snapshotsDir = path.join(dataDir, 'snapshots');
const baselineDir = path.join(dataDir, 'baseline');
const candidatesDir = path.join(dataDir, 'candidates');
const runLogsDir = path.join(rootDir, 'run-logs');
const resultsPath = path.join(rootDir, 'results.tsv');
const manifestPath = path.join(dataDir, 'manifest.json');
const remoteConfigUrl = 'https://feralfile-remote-configs.pages.dev/ff-app.json';
const sourceBuilderPath = path.join(repoRoot, 'scripts', 'build_feed_indexer_sqlite.js');
const sourceBuilderOutput = path.join(repoRoot, 'scripts', 'ff_feed_indexer_seed.sqlite');
const baselineOutput = path.join(baselineDir, 'baseline.sqlite');
const resultsHeader =
  'candidate\tbackend\tdb_size_mb\tsize_delta_mb\tavg_p95_ms\tmax_p95_ms\tlatency_score\tstatus\tnotes\n';

main().catch((error) => {
  console.error(error?.stack || String(error));
  process.exit(1);
});

async function main() {
  ensureDir(rootDir);
  ensureDir(dataDir);
  ensureDir(snapshotsDir);
  ensureDir(baselineDir);
  ensureDir(candidatesDir);
  ensureDir(runLogsDir);

  ensureCommand('node');
  ensureCommand('sqlite3');

  const snapshot = await fetchJson(remoteConfigUrl);
  const snapshotDate = new Date().toISOString().slice(0, 10);
  const snapshotPath = path.join(snapshotsDir, `ff-app.${snapshotDate}.json`);
  fs.writeFileSync(snapshotPath, `${JSON.stringify(snapshot, null, 2)}\n`);
  console.log(`[prepare] snapshot=${snapshotPath}`);

  console.log('[prepare] building baseline database with repo seed builder');
  execFileSync(
    'node',
    [
      sourceBuilderPath,
      '--channels-source',
      snapshotPath,
    ],
    {
      cwd: repoRoot,
      stdio: 'inherit',
    },
  );

  if (!fs.existsSync(sourceBuilderOutput)) {
    throw new Error(`Baseline seed database was not produced at ${sourceBuilderOutput}`);
  }

  fs.copyFileSync(sourceBuilderOutput, baselineOutput);
  console.log(`[prepare] baseline=${baselineOutput}`);

  const manifest = {
    preparedAt: new Date().toISOString(),
    remoteConfigUrl,
    snapshotPath,
    baselineDatabasePath: baselineOutput,
    sourceBuilderPath,
    sourceBuilderOutput,
  };
  fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
  console.log(`[prepare] manifest=${manifestPath}`);

  if (!fs.existsSync(resultsPath)) {
    fs.writeFileSync(resultsPath, resultsHeader);
    console.log(`[prepare] initialized=${resultsPath}`);
  }
}

function ensureCommand(command) {
  try {
    execFileSync(command, ['--version'], {stdio: 'ignore'});
  } catch {
    throw new Error(`${command} is required but was not found in PATH.`);
  }
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, {recursive: true});
}

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https
      .get(url, (response) => {
        if (response.statusCode && response.statusCode >= 400) {
          reject(new Error(`Failed to fetch ${url}: HTTP ${response.statusCode}`));
          response.resume();
          return;
        }
        const chunks = [];
        response.on('data', (chunk) => chunks.push(chunk));
        response.on('end', () => {
          try {
            const raw = Buffer.concat(chunks).toString('utf8');
            resolve(JSON.parse(raw));
          } catch (error) {
            reject(error);
          }
        });
      })
      .on('error', reject);
  });
}
