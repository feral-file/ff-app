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

- None.

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
- EV-03: FF1 connect/setup orchestration is centralized under a single orchestrator.
  - `FF1SetupOrchestrator` owns attempt lifecycle, cancellation semantics, and routing outcomes (as typed one-off effects).
  - Connect + Wi‑Fi screens are driven by orchestrator state/effects instead of page-local routing/dialog handlers.
  - Evidence:
    - `lib/app/providers/ff1_setup_orchestrator_provider.dart`: orchestrator lifecycle + effect emission + action methods.
    - `lib/app/ff1_setup/ff1_setup_effect.dart` + `lib/app/ff1_setup/ff1_setup_models.dart`: effect/state models.
    - `lib/app/providers/connect_ff1_providers.dart`: cancellation now has a stable `ConnectFF1Cancelled` state.
    - `lib/ui/screens/ff1_setup/connect_ff1_page.dart`: routes/dialogs consume orchestrator effects (fallback handles late listeners).
    - `lib/ui/screens/scan_wifi_network_screen.dart`: delegates Wi‑Fi actions + navigation to orchestrator.
    - `lib/ui/screens/send_wifi_credentials_screen.dart`: delegates Wi‑Fi submit + navigation/error handling to orchestrator.
    - Tests:
      - `test/unit/app/ff1_setup/ff1_setup_derivation_test.dart`
      - `test/unit/app/providers/ff1_setup_orchestrator_effects_test.dart`
      - `test/unit/ui/screens/ff1_setup/connect_ff1_page_widget_test.dart`
  - Verification:
    - `scripts/agent-helpers/post-implementation-checks.sh HEAD`
    - `flutter build apk --debug --flavor development`
    - `scripts/report_business_coverage.sh`
- EV-03 (Orbit 2): Gold-path CI separates **smoke** vs **endurance** evidence.
  - Smoke: PR job `gold-path-smoke`, fixed short soak (1 minute), artifact prefix
    `gold-path-smoke-ios-xcresult`.
  - Endurance: job `gold-path-endurance`, nightly schedule aligned with
    `nightly-integration.yml` (09:00 UTC), default long soak (240 minutes,
    overridable on `workflow_dispatch`), artifact prefix
    `gold-path-endurance-ios-xcresult`.
  - Shared implementation: `.github/actions/gold-path-patrol/action.yml`;
    workflow: `.github/workflows/gold-path-ui.yml`.
  - Manual dispatch uses input `run_profile` (`smoke` | `endurance`).
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
