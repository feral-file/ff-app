# Vision/Execution Gap Tracker

## Purpose
- Track gaps between intended product behavior and current implementation.
- Keep vision gaps and engineering refactors visible without mixing them into
  unrelated feature PRs.
- Provide a lightweight queue for follow-up work after shipping urgent fixes.

## How to use
- Keep entries outcome-focused (what user/system behavior is missing or brittle).
- Link each gap to owning flow(s) in `docs/project_spec.md` and
  `docs/app_flows.md`.
- Mark each item with scope and priority.
- Move completed items to a short history section instead of deleting context.

## Active gaps

### 1) Onboarding action controls need stable automation anchors
- Type: execution reliability + testability
- Priority: medium
- Affected flows:
  - Onboarding (No Deeplink)
  - Onboarding from Device Deeplink/QR
- Current gap:
  - Gold-path tests still rely on action labels like "Next"/"Finish" in parts
    of the flow, which can be non-hit-testable during async UI transitions.
- Desired state:
  - All primary onboarding actions use dedicated Patrol keys and test helpers
    target keys first, not text.

### 2) FF1 connect/setup orchestration remains distributed across providers
- Type: architecture simplification
- Priority: medium
- Affected flows:
  - FF1 Pairing and Wi-Fi Setup
  - Onboarding from Device Deeplink/QR
- Current gap:
  - Readiness, retries, and post-connect routing logic is spread across BLE
    transport + connect providers + page-level handlers.
- Desired state:
  - A single connect session orchestrator owns attempt lifecycle, cancellation,
    and routing outcomes.

## Refactor backlog (candidate follow-ups)
- Introduce `GoldPathPatrolKeys` for onboarding primary/secondary actions and
  migrate remaining label-based taps to key-based taps.
- Extract FF1 connect lifecycle into a dedicated session object (attempt id,
  readiness state, cancellation token, terminal outcome), then keep providers
  thin.
- Separate startup bootstrap into explicit phases (gate open, background sync,
  deferred recovery) with typed status events for UI/test observability.

## Completed items
- EV-02 (Orbit 2): Trust boundary for DP-1 playlist signatures is explicit;
  wire parsing for `signature` vs `signatures[]` is locked and regression-tested.
  - Trust boundary:
    - Feed/operator/pipeline sources own manifest production and any validation
      policy on their side. The mobile app does not perform cryptographic
      verification of DP-1 playlist signatures as a user trust signal in Orbit 2.
    - The app parses and stores signature material from feeds/APIs for interop
      and the local read model only (`signatures` on `Playlist`, wire
      `DP1Playlist.signatures`). Orbit 2 does not ship user-facing trust UI that
      implies app-side verification of those signatures (see issue #265).
  - Evidence:
    - `lib/domain/models/dp1/dp1_playlist.dart` — `dp1PlaylistSignaturesFromWire`,
      `DP1Playlist` wire model
    - `lib/domain/models/dp1/dp1_api_responses.dart` —
      `DP1PlaylistResponse._playlistFromJsonCompat`
    - `test/unit/domain/models/dp1/dp1_playlist_signatures_test.dart`
  - UI copy audit: no user-facing copy claims app-side DP-1 signature
    verification; address/domain verification and Wi-Fi test strings are
    unrelated flows.
- EV-01 ingest no longer flattens publisher attribution to a hardcoded
  default.
  - Evidence:
    - `scripts/build_feed_indexer_sqlite.js` now derives publisher attribution
      from source metadata when present and falls back to the feed/channel
      origin instead of forcing `Feral File`.
    - `test/scripts/build_feed_indexer_sqlite.test.js` covers:
      - publish-artifact origin-based attribution
      - `--channels-feed-endpoint` dryrun without hardcoded publisher naming
      - multi-source SQL generation with consistent `publishers` rows and
        `channels.publisher_id` linkage
    - Verification command:
      `node --test test/scripts/build_feed_indexer_sqlite.test.js`
- Seed-sync onboarding handshake now exposes bootstrap gate phases
  (`gate-open`, `sync-in-progress`, `deferred-recovery`) and blocks onboarding
  add-address actions only while startup seed sync is actively in flight.
