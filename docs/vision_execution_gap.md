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
- EV-01: Onboarding action controls now have stable automation anchors.
  - All onboarding action buttons (Next, Skip, Finish, Submit) use `GoldPathPatrolKeys`.
  - Gold-path test (`patrol_test/gold_path_test.dart`) taps all actions via key, not text.
  - Evidence:
    - `lib/app/patrol/gold_path_patrol_keys.dart`: Added `onboardingAddAddressSubmit` key.
    - `lib/ui/screens/add_address_screen.dart`: Submit button now uses the key.
    - `patrol_test/gold_path_test.dart`: Replaced `$('Submit').tap()` with key-based tap.
    - All onboarding CTA (shell-level) use dedicated patrol keys for reliable automation.
  - Verification: All primary/secondary onboarding actions tap via keys; no text-based action taps.
- EV-02 ingest no longer flattens publisher attribution to a hardcoded
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
