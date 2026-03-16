# Database Autoresearch

This folder adapts the reference `~/Documents/projects/autoresearch` workflow to the Feral File mobile app's local database cache.

The goal is to research database cache layouts that:

- reduce on-device database size without losing required data
- preserve full-text search for the fields the app depends on
- find the fastest read latency across the app's main local read paths

The harness is split by responsibility:

- `scripts/prepare.js`: fetches the latest remote-config snapshot, builds the baseline seed database, and stages research inputs
- `scripts/benchmark_core.dart`: backend-agnostic timing and aggregation utilities
- `scripts/query_benchmark.dart`: backend dispatcher for Dart-readable database benchmarks
- `scripts/sqlite_backend.dart`: current SQLite adapter mirroring SQL from [`app_database.dart`](/lib/infra/database/app_database.dart)
- `scripts/train.js`: creates candidate variants, runs the Dart benchmark, and records results
- `program.md`: optimized operating instructions for an autonomous research loop in this repo

## Why this shape

- Builder language: Node.js
  - The repo already contains a production-quality feed/indexer SQLite builder in [`/scripts/build_feed_indexer_sqlite.js`](/scripts/build_feed_indexer_sqlite.js)
- Reader language: Dart
  - The metrics engine is backend-agnostic and backend adapters can be added for any database that can be read from Flutter/Dart
  - The current adapter is SQLite, but the harness is intentionally structured so other backends can be plugged in later

## Commands

Prepare inputs:

```bash
node autoresearch/scripts/prepare.js
```

Run candidate benchmarking:

```bash
dart run autoresearch/scripts/train.dart
```

Or run the Node orchestrator directly:

```bash
node autoresearch/scripts/train.js
```

## Generated artifacts

- `data/snapshots/`: fetched copies of `ff-app.json`
- `data/baseline/`: baseline database copied from the repo seed builder
- `data/candidates/`: candidate databases
- `results.tsv`: benchmark history
- `last_run_summary.json`: latest summarized results

## Current benchmark scope

The Dart benchmark replays the app's main local query families:

- channels list paging
- playlists list loading
- channel detail lookup
- playlist detail lookup
- playlist items by position and provenance
- channel preview item loading
- works paging and item-id paging
- work detail lookup
- FTS search for channels, playlists, and works

Watch streams are intentionally not benchmarked as streams because they add debounce/reactivity overhead that would drown out the underlying storage cost. Instead, the benchmark targets the concrete query methods those streams depend on.
