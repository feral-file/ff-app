# Workers Design

## Scope
This document is the source of truth for worker design under `lib/infra/workers`.

It defines:
- Worker roles and boundaries.
- Message protocol and scheduler routing.
- Pause/stop/resume/fresh-start lifecycle behavior.
- How to add or update worker implementations.

## Current Files and Responsibilities

| File | Responsibility |
| --- | --- |
| `lib/infra/workers/worker_scheduler.dart` | Global lifecycle orchestration; delegates to IndexAddressWorkersFleet |
| `lib/infra/workers/background_worker.dart` | Shared worker lifecycle/state/checkpoint contract + isolate lifecycle primitives |
| `lib/infra/workers/worker_message.dart` | Inter-isolate opcode/message protocol |
| `lib/infra/workers/worker_state_service.dart` | Persistent worker state/checkpoint storage |
| `lib/infra/workers/index_address_worker.dart` | Address indexing/polling/token-ingest workflow |
| `lib/infra/workers/worker_fleet.dart` | Fleet abstraction for IndexAddressWorkersFleet |
| `lib/infra/workers/worker_database_session.dart` | Utility for lazy worker DB session lifecycle |

**Removed** (feed data now comes from seed database):
- `ingest_feed_worker.dart` — feed-ingested signal intake and query trigger emission
- `item_enrichment_query_worker.dart` — bare-item query and batching workflow
- `enrich_item_worker.dart` — batch metadata enrichment and persistence workflow

## Core Design
- Workers are isolate-backed execution units.
- `WorkerScheduler` is the only coordinator for lifecycle and fleet management.
- Worker interaction is message-based via `WorkerMessage`; workers do not call
  each other directly for business flow.
- Address workers write to DB via the main-isolate `DatabaseService`; no
  per-worker Drift isolate is needed.

## Architecture

### Main Isolate
- `WorkerScheduler` initializes worker instances lazily.
- Scheduler owns app lifecycle transitions:
  - foreground: `startOnForeground()`
  - background: `pauseOnBackground()`
  - shutdown/reset: `stopAll()`

### Worker Isolates
- Workers spawn their own isolate on start.
- Workers receive opcode messages from scheduler/main isolate.
- Workers return typed state/progress/work-complete messages.

## Worker Workflow Details

### `IndexAddressWorker`
- Purpose: run address indexing workflow and ingest tokens for personal playlists.
- Input: address assignments.
- Internal state: pending address queue + in-flight address.
- Output: `workComplete` or `workFailed`.
- Fleeted: one logical worker per address via `IndexAddressWorkersFleet`.

## Message Protocol
`lib/infra/workers/worker_message.dart` defines shared opcodes.

### Scheduler/Main -> Worker
- `start`
- `pause`
- `stop`
- `enqueueWork`

### Worker -> Scheduler/Main
- `workComplete`
- `workFailed`
- `stateChanged`
- `progressUpdate`

### Lifecycle ACK
For graceful lifecycle transitions, isolates emit:
- `{ "type": "lifecycleAck", "action": "pause|stop" }`
after loop/input drain and DB close.

## Lifecycle Contract

| Workflow | Pause | Stop | Resume | Fresh Start |
| --- | --- | --- | --- | --- |
| `IndexAddressWorker` | Save address queue/in-flight checkpoint, stop polling loop, close isolate DB | Stop polling/input, close isolate DB, clear queue/checkpoint, set stopped state | Restore queued addresses and continue indexing | Clear persisted queue/checkpoint and restart empty |
| `WorkerScheduler` | Pause all started workers; keep checkpoints for resume | Stop all workers, clear checkpoints, reset runtime | Resume paused workers via `resume()` | Reinitialize workers with empty runtime and no stale checkpoint |

### Required Ordering
- Pause sequence:
  1. Save checkpoint
  2. Request graceful pause
  3. Receive lifecycle ack
  4. Persist paused state
- Stop sequence:
  1. Request graceful stop
  2. Receive lifecycle ack
  3. Reset in-memory work state
  4. Persist stopped state with null checkpoint

## Stop-State Guardrails
Workers must reject new incoming business actions while in `stopped` state.
Examples:
- `IndexAddressWorker.enqueueAddress()` no-op when stopped.

## Add A New Worker
Use this checklist when introducing a new worker under `lib/infra/workers`.

### Naming and File Conventions
- Class name: `<VerbOrDomain><Noun>Worker` in `PascalCase`.
- File name: matching `snake_case`, for example `sync_inventory_worker.dart`.
- Worker ID: stable string in scheduler/fleet construction; keep lowercase and
  scoped where needed.

### Required Structure
- Extend `BackgroundWorker`.
- Implement:
  - `onStart()`
  - `onPause()`
  - `onStop()`
  - `buildCheckpoint()`
  - `restoreFromCheckpoint()`
  - `resetWorkState()`
  - `onIsolateMessage()`
  - `hasRemainingWork`
- Add isolate entrypoint + receive loop in the worker file.
- Handle lifecycle control opcodes (`pause` and `stop`) in isolate code.
- Close worker DB runtime before sending lifecycle ack.

### Scheduler and Routing Integration
- Instantiate the worker in `WorkerScheduler` (or an appropriate fleet).
- Wire start/pause/stop transitions.
- If pooled, add/update a fleet in `worker_fleet.dart`.

### Persistence and Resume
- Define a minimal checkpoint payload shape.
- Ensure paused state restores enough information to continue safely.
- Ensure stop clears checkpoint and in-memory queue/state.
- Ensure stopped worker APIs reject new business inputs.

### Tests to Add
- Worker unit tests for:
  - checkpoint on pause
  - clear on stop
  - resume restore
  - stopped input guard
  - isolate start/stop behavior
- Integration coverage for scheduler orchestration/routing of the new worker.

## Update Existing Worker
When changing an existing worker:

1. Update this doc if responsibilities, routing, lifecycle, or checkpoint schema
   changes.
2. Keep opcode compatibility unless all call sites and tests are updated in the
   same change.
3. Preserve graceful lifecycle ordering (checkpoint/ack/close semantics).
4. Preserve scheduler-centric routing (no direct cross-worker calls).
5. Update unit and integration tests for any changed behavior.
