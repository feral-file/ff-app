# Vision/Execution Gap Tracker — Orbit 3

## Purpose

- Define the execution contract for Orbit 3.
- Translate roadmap outcomes into buildable, testable, evidence-backed work.
- Keep this document implementation-focused; keep the roadmap outcome-focused.

## Contract sources

- Strategy: `https://github.com/feral-file/docs-private/blob/main/strategy/strategy-onepager.md`
- Roadmap scope: `https://github.com/feral-file/docs-private/blob/main/strategy/orbit-roadmap.md`
- Product contract: `docs/project_spec.md`
- Flow contract: `docs/app_flows.md`
- DP-1 core spec: `https://raw.githubusercontent.com/display-protocol/dp1/refs/heads/main/core/v1.1.0/spec.md`

## Adjacent docs and scoping

- `docs/vision_execution_gap.md` tracks active implementation and refactor gaps.
- `docs/vision_gap_orbit3.md` tracks Orbit 3 planning and execution contracts.
- Keep Orbit 2 closure items in Orbit 2 tracker/docs; do not move unresolved Orbit 2 work into this document.

## Orbit 3 guardrails

- DP-1 vocabulary remains `Channel`, `Playlist`, `Work`.
- Discovery changes must stay deterministic and explainable.
- Trust UX must never claim verification the system does not actually perform.
- Orbit 3 is foundation work, not a full personalization or ranking program.

## Status model

- `planned`: not started
- `in progress`: active implementation
- `aligned`: shipped and verified against acceptance evidence

## Orbit 3 execution matrix

### O3-01 · Source grouping for Channels

- Outcome: top-level channel browsing is source-aware and avoids overload from high-volume publishers.
- Status: planned
- In scope:
  - source-group summaries for non-personal channels
  - source-group drill-in to sub-channel lists
  - deterministic mapping + fallback behavior
- Out of scope:
  - grouping rollout for Playlists and Works in this first slice
  - algorithmic ranking/personalization systems
- Acceptance evidence:
  - home/view-all channels no longer present long adjacent runs from one high-volume source
  - route + provider tests for source-group drill-in and pagination
  - deterministic grouping behavior across seed refresh and app restart
- Dependencies: O3-05 publisher contract finalized
- Notes: design reference in `docs/plans/publisher_grouping_ia_spec.md`

### O3-02 · Me/Curated/Global IA parity contract

- Outcome: Me/Curated/Global segmentation is explicit, consistent, and documented across Channels/Playlists/Works.
- Status: planned
- In scope:
  - final IA decision and explicit contract in docs
  - implementation for surfaces required by Orbit 3 scope
  - route and navigation consistency checks
- Out of scope:
  - broad home redesign beyond parity and clarity
  - experimental IA variants
- Acceptance evidence:
  - updated `docs/project_spec.md` and `docs/app_flows.md` with final segmentation definitions
  - UI verification on home and view-all surfaces for all three object types
  - no regression in existing playback entry paths
- Dependencies: O3-01 source grouping behavior and O3-05 semantics

### O3-03 · Trust legibility as an honest user-visible signal

- Outcome: users can see trust state that maps directly to real verification evidence.
- Status: planned
- In scope:
  - explicit trust-state model for user-facing surfaces
  - signal rendering rules (verified, unverified, unavailable)
  - explicit trust boundary between pipeline validation and app UX
- Out of scope:
  - endorsement marketplace or social reputation systems
  - claims beyond current verification evidence model
- Acceptance evidence:
  - trust state contract documented and linked to verification source
  - tests for payload compatibility (`signature` and `signatures[]`) and trust-state mapping
  - UI and docs copy confirm no trust overclaims
- Dependencies: O3-05 publisher/trust semantics contract

### O3-04 · Deterministic discovery expansion beyond local search baseline

- Outcome: discovery improves beyond current local-only behavior without sacrificing determinism.
- Status: planned
- In scope:
  - minimal discovery enhancements tied to source and trust clarity
  - deterministic sort/filter surfaces that are explainable to users
- Out of scope:
  - conversational assistant discovery
  - opaque recommendation/ranking engines
- Acceptance evidence:
  - measurable discovery path added (and documented) without non-deterministic ranking
  - integration tests for new discovery routes/providers
  - updated flow docs for search/discovery behavior
- Dependencies: O3-01 and O3-03 complete enough to ground discovery signals

### O3-05 · Publisher/source semantics formalized in app contract

- Outcome: publisher/source behavior is formally defined and consistent across ingest, ordering, trust, and navigation.
- Status: planned
- In scope:
  - canonical source-group key contract and fallback order
  - deterministic naming/override policy for known major sources
  - product/spec language for publisher semantics
- Out of scope:
  - protocol-level expansion of DP-1 object model
  - broad taxonomy framework beyond immediate Orbit 3 needs
- Acceptance evidence:
  - documented contract in `docs/project_spec.md` and relevant implementation docs
  - ingest/build tests prevent attribution collapse and unstable naming
  - source semantics are traceable from artifact -> DB fields -> UI grouping behavior
- Dependencies: none (this is the foundation item)

## Sequencing and exit criteria

1. **Phase A: semantics and trust boundary**
   - Items: O3-05, O3-03 (contract first)
   - Exit: publisher and trust claims are explicit, test-backed, and reviewable.
2. **Phase B: channels source-group IA**
   - Items: O3-01
   - Exit: source-group browsing works end-to-end and remains deterministic.
3. **Phase C: IA parity alignment**
   - Items: O3-02
   - Exit: Me/Curated/Global behavior is consistent and documented.
4. **Phase D: discovery expansion**
   - Items: O3-04
   - Exit: discovery is improved with deterministic behavior and no trust overclaims.

## Definition of done (Orbit 3)

- All O3 items marked complete with linked evidence.
- `docs/project_spec.md` and `docs/app_flows.md` updated to match shipped behavior.
- Trust and source semantics are test-backed and user-facing claims are accurate.
- No regression to Orbit 2 publish -> ingest -> surface -> play reliability path.
