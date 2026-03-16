# Feral File DB Autoresearch

This program adapts the original autoresearch idea to database-cache optimization for the Feral File mobile app.

## Mission

Improve the local database caching strategy used by the app's offline-first DP-1 read model.

Primary goals:

1. Reduce the database file size while preserving the data needed by the app.
2. Preserve required full-text search coverage for channel, playlist, work title, and work artist fields.
3. Find the best latency across the app's main local query families.

Constraints:

- The builder can be written in any language.
- The database reader must stay Flutter-readable.
- Do not break the app's offline-first read-path assumptions.
- Do not remove fields the app still needs.
- Do not remove FTS coverage for required fields.

## In-scope files

Read these first:

- [docs/project_spec.md](../docs/project_spec.md)
- [docs/app_flows.md](../docs/app_flows.md)
- [lib/infra/database/app_database.dart](../lib/infra/database/app_database.dart)
- [lib/infra/database/database_service.dart](../lib/infra/database/database_service.dart)
- [lib/app/providers/search_provider.dart](../lib/app/providers/search_provider.dart)
- [lib/app/providers/channels_provider.dart](../lib/app/providers/channels_provider.dart)
- [lib/app/providers/playlists_provider.dart](../lib/app/providers/playlists_provider.dart)
- [lib/app/providers/works_provider.dart](../lib/app/providers/works_provider.dart)
- [lib/app/providers/channel_preview_provider.dart](../lib/app/providers/channel_preview_provider.dart)
- [lib/app/providers/playlist_details_provider.dart](../lib/app/providers/playlist_details_provider.dart)
- [scripts/build_feed_indexer_sqlite.js](../scripts/build_feed_indexer_sqlite.js)
- [autoresearch/scripts/benchmark_core.dart](./scripts/benchmark_core.dart)
- [autoresearch/scripts/prepare.js](./scripts/prepare.js)
- [autoresearch/scripts/query_benchmark.dart](./scripts/query_benchmark.dart)
- [autoresearch/scripts/sqlite_backend.dart](./scripts/sqlite_backend.dart)
- [autoresearch/scripts/train.js](./scripts/train.js)

## Setup

1. Verify `node`, `dart`, and `sqlite3` are available.
2. Run:

```bash
node autoresearch/scripts/prepare.js
```

3. Confirm these files exist:
   - `autoresearch/data/snapshots/*.json`
   - `autoresearch/data/baseline/baseline.sqlite`
   - `autoresearch/results.tsv`

4. Establish the baseline:

```bash
node autoresearch/scripts/train.js --candidate baseline
```

## What you can change

You may change:

- `autoresearch/scripts/train.js`
- `autoresearch/scripts/query_benchmark.dart`
- `autoresearch/scripts/benchmark_core.dart`
- backend adapter files under `autoresearch/scripts/`
- helper files under `autoresearch/`

The metrics engine is backend-agnostic. Keep backend-specific logic isolated in
adapter files so the research is not limited to SQLite.

You may also propose changes to the upstream seed builder if that unlocks materially better database layouts, but prefer keeping production code unchanged unless the gain is clear.

## What you should optimize

Trade off these dimensions explicitly:

- database size on disk
- p95 latency per query family
- worst-case p95 across all query families
- lowest overall latency score across all compared solutions
- simplicity of the resulting storage design

Prefer simpler wins over clever complexity when the performance difference is small.

## Evaluation rules

Every run must record:

- candidate name
- file size
- size delta vs baseline
- average p95 latency across benchmark scenarios
- worst p95 latency across benchmark scenarios
- latency score used for ranking solutions
- short notes describing the storage strategy

## Suggested research directions

- non-SQLite storage engines that remain Flutter-readable
- precomputed read models for the works ordering hotspot
- page-size and vacuum tuning
- `ANALYZE` / `PRAGMA optimize`
- targeted covering indexes for hot list queries
- FTS maintenance and optimization
- schema compaction that keeps the same reader contract
- alternative storage layouts that remain Flutter-readable

Be skeptical of strategies that improve one query while bloating the file or harming search.

## Loop

1. Inspect the latest `results.tsv`.
2. Pick one concrete candidate idea.
3. Implement it in the autoresearch harness.
4. Run:

```bash
node autoresearch/scripts/train.js
```

5. Compare against baseline.
6. Keep only changes that improve the score in a meaningful way or materially simplify the design.

If a run crashes, record it and move on.