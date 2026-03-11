# ADR: Orbit 2 Casey v1 Minimum

Date: 2026-03-07
Status: Accepted

## Decision

Orbit 2 minimum is the publishing/playback spine only:

1. Publisher can publish DP-1 channel/playlist with strict machine-readable artifact.
2. App ingest path removes manual channel URL drift while preserving seed-DB-first runtime.
3. Published channel appears in existing curated/global surfaces and plays via canonical JSON -> FF1 path.
4. Canary path includes reproducible >=4h playback evidence.

## Constraints

- No new app IA.
- Exhibitions remain channels.
- Played objects remain playlists/works.
- No runtime feed-first migration required.
- No new endorsement shelves.

## Channel selection policy (Orbit 2)

- Feed `/channels` remains the authoritative object source.
- Default app snapshot ingestion remains curated-selector driven (`channels_source`).
- Full-feed ingestion is optional/explicit (`feed_endpoint`) and not the default operational path.
- Broad user-facing add/follow of arbitrary external channels is deferred to Orbit 3+ trust/discovery work.

## Explicit cuts

- Partner-controller/delegated auth work.
- Scheduling.
- Licensing/rights enforcement.
- Advanced bubbling/discovery frameworks.

## Why

This aligns with updated Orbit roadmap and current app/runtime reality while reducing operational drift and improving reliability with minimal change surface.
