# AGENTS.md — Workers

## Scope
This file applies to all files under `lib/infra/workers/`.

## Required reference
Before changing any worker code, read and follow:
- `/Users/anhnguyen/Documents/projects/ff-app/docs/workers.md`

Treat `/docs/workers.md` as the single source of truth for:
- worker responsibilities and boundaries
- scheduler routing behavior
- isolate message-passing model
- lifecycle contract (`pause` / `stop` / `resume` / `fresh start`)
- graceful shutdown ordering and DB-close requirements

## Editing constraints
- Do not introduce direct worker-to-worker business coupling.
- Keep `WorkerScheduler` as coordinator; workers remain execution units.
- Preserve stopped-state input guards and checkpoint semantics.
- If lifecycle/routing/responsibilities change, update `/docs/workers.md` in
  the same change.
