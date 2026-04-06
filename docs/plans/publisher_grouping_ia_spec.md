# Publisher Grouping IA Spec (Draft)

## Status
- Draft for team review.
- Goal: align product vision with implementation plan before coding.
- Current team direction for Orbit 2: do not add new Channel IA yet; use editorial ordering as an interim mitigation.

## Problem
- Channel browsing is currently flat at the top level for large sources.
- High-volume sources (for example, Feral File with 50+ channels) dominate the list and reduce discoverability.
- This creates similar overload for other sources (for example, Objkt).

## Desired Product Outcome
- Users first browse by source-level group (publisher-like grouping), then drill into sub-channels.
- Top-level Channel browsing remains scan-friendly even when a source publishes many channels.
- DP-1 vocabulary remains unchanged (Channel/Playlist/Work): grouping is a presentation/discovery layer, not a new protocol object.

## Scope

### In scope
- Channels IA in Home + "View all" pathways.
- Source/group shelf UI and drill-in behavior.
- Minimal data-layer support to derive stable source groups from existing channel metadata.
- Documentation updates in `docs/project_spec.md` and `docs/app_flows.md` once design is accepted.

### Out of scope
- New DP-1 object types.
- Follow/share/star feature rollout.
- Full Explore redesign (conversational/faceted).
- Playlists/Works grouping implementation in this first slice (can follow after Channel grouping proves out).

## Definitions
- **Source group**: UI grouping key derived from channel metadata that represents a publishing source (examples: "Feral File", "Objkt").
- **Sub-channel**: a normal DP-1 Channel shown inside a selected source group.

## UX Proposal (v1)

### Home > Channels tab
- Keep `Me` section behavior unchanged.
- Replace/augment current flat `Curated` section with a `Global`/source-oriented section that shows source groups.
- Each source group row shows:
  - source name
  - channel count
  - optional cover/preview treatment
- Tapping a source group opens source detail listing its sub-channels.

### All Channels
- Entry points support:
  - all source groups
  - direct source-group detail
  - direct channel detail (existing)
- For large source groups, support pagination in sub-channel list.

### Source detail behavior
- Header: source identity + short description (if available).
- Body: sub-channel list ordered by existing curated logic (or explicit ordering if metadata provides one).
- Channel tap behavior remains unchanged (open channel detail).

## Information Architecture Rules
- Preserve existing `Me` semantics for local/personal channels.
- Introduce explicit top-level source-group browsing for non-personal channels.
- Avoid inventing a new persisted domain entity initially; derive groups from existing channel metadata first.

## Data and Mapping Rules (Draft)
- Derive `sourceGroupKey` from channel metadata with deterministic fallback:
  1. explicit publisher/source field (if present)
  2. known channel metadata mapping
  3. fallback bucket: `Other Sources`
- Keep allowlist/override mapping for known major sources (initially `Feral File`, `Objkt`) to ensure stable naming and grouping.
- Grouping must be deterministic across app restarts and seed refreshes.

## Routing and State Impact
- Add source-group route(s) for drill-in (for example: `/channels/sources/:sourceKey`).
- Keep channel detail routes unchanged.
- Add provider(s) for:
  - source group summaries
  - paginated sub-channel list by source group

## Rollout Strategy

### Orbit 2 interim plan (approved direction)
- Keep current flat Channel UI (no publisher grouping routes/screens this Orbit).
- Do not introduce a new `Global` shelf in app UI this Orbit.
- Keep full channel ingestion so `View all` still shows the long tail.
- Promote a fixed set of **10 featured channel IDs** to the top of top-level Channel ordering.
- Featured IDs are editorially curated (for example, mixed across Feral File and Objkt) and rotated intentionally, not algorithmically.
- Implement this in source/build ordering (for example, `channels_source` and/or snapshot build input), not by adding new app-side ranking logic.

### Phase 1 (recommended first implementation)
- Implement source grouping for Channels only.
- Keep Playlists/Works behavior unchanged.
- Validate usability and performance with high-volume sources.

### Phase 2
- Apply the same grouping strategy to Playlists and Works where applicable.
- Align final IA with private product spec Me/Curated/Global outcomes.

## Acceptance Criteria
- Top-level Channels no longer shows dozens of adjacent rows for a single high-volume source.
- Users can open `Feral File` and see its sub-channels in one drill-in surface.
- Users can open `Objkt` and see its sub-channels similarly.
- Existing personal (`Me`) behavior is unaffected.
- Existing channel detail/playback entry flows continue to work without regression.

## Telemetry and Observability
- Track source-group impressions and opens.
- Track source-detail to sub-channel click-through.
- Track latency for source-group and sub-channel list loading.

## Test Plan (high-level)
- Unit:
  - source-group mapping and fallback logic
  - deterministic ordering and grouping behavior
- Integration:
  - route/load for source group detail
  - seed refresh does not break source grouping stability
- UI:
  - Home Channels renders grouped sources for high-volume feeds
  - drill-in to sub-channel list and open channel detail

## Risks and Open Questions
- Which metadata field is canonical for source grouping across all feeds?
- Should `Curated` and `Global` be separate shelves, or should source-grouping define `Global` while `Curated` remains editorial?
- Should we cache source-group summaries separately for faster initial render?

## Task Breakdown (post-approval)
1. Finalize grouping key contract and source overrides.
2. Add provider layer for source-group summaries and source-detail channels.
3. Add routes and screens for source-group detail.
4. Update Channels tab and All Channels entry points.
5. Add tests (unit/integration/UI).
6. Update `docs/project_spec.md`, `docs/app_flows.md`, and `docs/vision_execution_gap.md` status.
