# Project Spec

## Document contract

- This document is the canonical product contract for the mobile app.
- It defines product intent, system boundaries, flow outcomes, and invariants.
- When `project_spec.md` conflicts with lower-level docs, this file wins.
- `docs/app_flows.md` must stay consistent with this contract and only expand
  execution detail (routes, transitions, failure handling).
- Any change to onboarding/address indexing/FF1 behavior should update this doc
  first, then update `docs/app_flows.md` in the same change.

## 1. Purpose of the app

- The app is the mobile controller and library browser for The Digital Art System.
- It solves two practical problems for users:
  - reliably browsing and selecting digital art content (DP-1 Channel/Playlist/Work) even when network conditions vary
  - connecting to and controlling FF1 devices for playback in real spaces
- Primary users today are:
  - people browsing curated/public DP-1 content
  - collectors adding wallet addresses to build a personal "My Collection" view
  - FF1 owners pairing devices, configuring display settings, and controlling playback

## 2. Product/system context

- This repository is a Band 4 Presentation App in the Feral File multi-band system.
- It consumes data and services from other bands:
  - Discovery/content and indexer APIs (read/search/enrichment)
  - ownership/indexing infrastructure for wallet-based personal collection flows
  - FF1 relayer/control endpoints for device connectivity and commands
- It does not own:
  - canonical publication/curation backoffice
  - trust/licensing backend policy decisions
  - FF OS runtime behavior on device
- In product terms, the app is the handheld control surface for FF1 (and conceptually FF1+FFP), with offline-first local data as the default read path.

## 3. Main user flows

### Flow: App startup and bootstrap

- Trigger: app launch or app resume.
- Key steps:
  - load env config and initialize logging/Sentry
  - decide initial route from onboarding state + legacy DB detection
  - run startup bootstrap (seed DB sync, bootstrap service, pending address migration, indexing resume)
  - start deep link handling and app lifecycle watchers
- Outcome: app reaches home or onboarding with providers/services initialized.
- Important edge cases:
  - missing required env keys: app blocks and shows configuration error screen
  - **First install (no `dp1_library.sqlite` yet):** startup seed sync may fail
    or skip while offline; `SeedDatabaseGate` stays **pending** until a successful
    download places the file. The app runs **lightweight bootstrap** (config +
    FF1 auto-connect watcher only—no Drift open) so startup can still complete
    to onboarding/home. Home tabs show retryable loading until the seed exists.
    Full DP-1 bootstrap (My Collection channel, DB-backed feeds) runs only after
    the file exists—on first successful sync or a later resume/retry
    (`pendingDp1BootstrapAfterSeed`).
  - **Existing local seed file:** seed sync failure generally continues using the
    on-disk DB; gate completion follows normal sync outcome (see seed services).
  - legacy data exists: onboarding is marked seen and migration runs in background

### Flow: Onboarding and first-use setup

- Trigger: user without onboarding completion (or forced reset path).
- Key steps:
  - onboarding introduce page
  - optional add address (with optional alias)
  - optional FF1 setup path via device picker
  - finish marks onboarding complete and routes to home
- Outcome: user enters app with onboarding flag persisted.
- Important edge cases:
  - while startup seed sync is actively in flight, onboarding add-address
    actions wait for the bootstrap gate to reopen so first-run transitions stay
    deterministic
  - if seed DB is not ready, added addresses are queued in pending store and migrated later
  - if onboarding is entered from device-connect deep link, flow branches to connect FF1

### Flow: Browse and discover content

- Trigger: user opens home index.
- Key steps:
  - browse tabs (Playlists, Channels, Works)
  - open list/detail routes (all channels/playlists, channel detail, playlist detail, work detail)
  - use search screen for channels/playlists/works with filters and suggestions
- Outcome: user finds content and can drill into details.
- Important edge cases:
  - loading/error states shown for seed sync and local fetch failures
  - search is local-DB driven; no remote conversational/voice agent path currently implemented

### Flow: Add wallet/domain address and build personal collection

- Trigger: add address from onboarding or home menu.
- Key steps:
  - validate Ethereum/Tezos address or ENS/TNS domain
  - reject duplicates (including pre-seed pending addresses)
  - optional alias capture (domain inputs may auto-complete directly)
  - create/update address playlist, track address, start index/sync flow
- Outcome: personal address-based playlists appear in "Me" sections and receive indexed tokens.
- Important edge cases:
  - indexing can resume from persisted workflow state after app restart
  - background fast-path sync runs before polling completes
  - remove address deletes playlist + related local token items and clears app state anchors/status

### Flow: FF1 setup and connection

- Trigger: FF1 setup from onboarding/device menu/deep link/QR.
- Key steps:
  - discover FF1 via BLE scan or resolve from deeplink info
  - connect via BLE and read device info
  - if internet/topic not ready, run Wi-Fi network scan + credential flow
  - persist device in ObjectBox and set active device
  - navigate to device configuration
- Outcome: active FF1 device is paired and auto-connects to relayer.
- Important edge cases:
  - BLE retries/backoff and "still connecting" fallback UI
  - FF1 response errors route to support/contact dialogs
  - device-updating/version errors route to dedicated update handling

### Flow: Play and control on FF1

- Trigger: user taps Play/Display from work or playlist detail; or uses now-displaying controls.
- Key steps:
  - build DP-1 playlist payload (single work or full playlist)
  - cast to selected device through canvas/relayer client
  - consume live player/device status via Wi-Fi control streams
  - now-displaying bar shows current item and allows navigation to work detail
  - optional: use keyboard/touchpad interactions for remote control
- Outcome: art is playing on FF1 with live status visible in app overlays/screens.
- Important edge cases:
  - no active device: now-displaying bar shows pair/connect guidance (invisible when not pairing)
  - disconnected state: now-displaying bar reflects connection transitions
  - enrichment failures do not block playback UI (fallback DP-1 item data remains)
  - now-displaying stays aligned with live FF1 playback: enrichment uses local data when available and DP-1 fallback otherwise; same-playlist window changes (index shifts or scroll expansion) update immediately with DP-1 fallback rows while the cache/enrichment pass fills them in, and the bar avoids a loading flash except when the playing **list** from FF1 changes (see `docs/app_flows.md` for window and overlay behavior).

### Flow: Maintenance and recovery

- Trigger: settings actions or remote config checks.
- Key steps:
  - force-update check from remote config and blocking update overlay
  - rebuild metadata (replace DB from seed + refetch)
  - "Forget I exist" clears local DB/ObjectBox/cache and returns to onboarding
  - support email composes logs/device info context
- Outcome: user can recover local state and keep app/device healthy.
- Important edge cases:
  - cleanup timeout/failure still routes user back to onboarding
  - rebuild metadata preserves known personal addresses before refetch

## 4. Major functionalities

- DP-1 browsing (Channels/Playlists/Works)
  - What: home tab browsing, list/detail pages, local search.
  - Who: all app users.
  - Touches: `lib/ui/screens/*`, `channels_provider`, `playlists_provider`, `works_provider`, Drift DB.
- Address-based personal collection
  - What: add/remove wallet/domain addresses, create address playlists, index/sync tokens.
  - Who: collectors/stewards.
  - Touches: `add_address_provider`, `AddressService`, `DomainAddressService`, indexer services, AppStateService.
- FF1 pairing and device connectivity
  - What: BLE discovery/connection, Wi-Fi credential setup, active-device persistence.
  - Who: FF1 owners.
  - Touches: `ff1_providers`, `connect_ff1_providers`, `connect_wifi_provider`, ObjectBox device service.
- FF1 playback and remote control
  - What: cast DP-1 payloads, live device/player status, now-displaying + keyboard/touch controls.
  - Who: paired-device users.
  - Touches: canvas client, `ff1_wifi_*` providers/control/transport, now-displaying providers/UI.
- Offline-first seed database lifecycle
  - What: startup seed download/swap by ETag, `SeedDatabaseGate`, first-install
    lightweight bootstrap vs full DP-1 bootstrap after the file exists, rebind/
    invalidation, resume/retry sync.
  - Who: all users (infrastructure behavior).
  - Touches: `seed_database_*` services/providers, `App` bootstrap orchestration,
    `bootstrap_provider` (`bootstrapWithoutDp1Library`, `pendingDp1BootstrapAfterSeed`).
- Release/update/support utilities
  - What: release notes fetch + display, force update overlay, support email, local data cleanup flows.
  - Who: all users/support workflows.
  - Touches: release notes service/providers, remote config/force update services, overlay + cleanup providers.

## 5. Important screens

### Screen: HomeIndexPage

- Purpose: main content entry with tabbed browsing and utility menu.
- Entry points: `/`.
- Key actions: switch tabs, open search, open settings/release notes/support, open add-address, open FF1 config.
- Important data: tab provider state, seed-download state, active FF1 pairing status.
- Related modules: `home_index_page.dart`, tab screens, `seedDownloadProvider`, `activeFF1BluetoothDeviceProvider`.

### Screen: SearchTabPage

- Purpose: search channels/playlists/works from local model with filters/suggestions.
- Entry points: search icon in home header.
- Key actions: submit query, tap suggestions/results, apply type/source/date/sort filters.
- Important data: search providers + local DB query results.
- Related modules: `search_provider.dart`, search filter widgets/models.

### Screen: AllChannels / ChannelDetail

- Purpose: browse full channel lists and inspect one channel's playlists.
- Entry points: curated/personal "View all", `/channels/:channelId`.
- Key actions: refresh/load more/open playlist or work.
- Important data: channel list, channel metadata, playlists in channel.
- Related modules: `channels_provider`, `channel_detail_provider`, DB service.

### Screen: AllPlaylists / PlaylistDetail

- Purpose: browse full playlists and inspect one playlist's works.
- Entry points: curated/personal "View all", `/playlists/:playlistId`.
- Key actions: refresh/load more, play on FF1, open work, delete personal playlist/address mapping.
- Important data: playlist metadata, items, channel subtitle, owner address state.
- Related modules: `playlists_provider`, `playlist_details_provider`, `canvasClientServiceV2`, address service.

### Screen: WorkDetail

- Purpose: detailed work view with back-layer media preview and metadata/provenance sections.
- Entry points: `/works/:workId` from tabs/search/details.
- Key actions: play on FF1, open external links, rebuild metadata for work, expand info panel.
- Important data: playlist item core data plus optional indexer token enrichment.
- Related modules: `workDetailStateProvider`, `IndexerService`, DB converters, FF display button.

### Screen group: Onboarding (Introduce, OnboardingAddAddress, OnboardingSetupFf1)

- Purpose: first-use orientation, optional personal collection seeding, optional FF1 setup.
- Entry points: `/onboarding/*`, startup routing.
- Key actions: add/remove addresses, skip/next, launch FF1 setup path, finish onboarding.
- Important data: onboarding flag, tracked addresses, deeplink payload continuity.
- Related modules: onboarding providers, add-address flow, token sync coordinator.

### Screen group: FF1 setup (FF1DeviceScan, StartSetupFf1, ConnectFF1, ScanWiFi, EnterWiFiPassword, DeviceConfig, FF1Updating)

- Purpose: discover/pair FF1 and configure connectivity/device settings.
- Entry points: onboarding setup, menu FF1 Settings, QR deeplinks.
- Key actions: BLE scan/connect, Wi-Fi selection/credentials, finalize pairing, adjust orientation/scaling/audio (FF1 system), adjust FFP/DDC display brightness/contrast/power (no monitor volume/mute in app).
- Firmware updates: Device Configuration can prompt when a newer version is reported (only after setup, not during the initial setup visit); eligibility is re-checked when relayer connectivity or version fields change so a late relayer connection still surfaces the prompt; at most one auto-prompt dialog is scheduled or open at a time. If the reported latest version changes during the same visit, the prompt may appear again for the new version (subject to dismissal). Manual **Update FF1** is shown only when the relayer has already reported both `installedVersion` and `latestVersion`; the prompt and manual action both start the update over Wi-Fi/relayer only (no Bluetooth firmware update from the app). Prompt orchestration (session dedupe, in-flight guard) and relayer update start live in app-layer code shared by the screen and options entry points.
- Important data: BLE state, FF1 device info/topicId, device/player status streams.
- Related modules: FF1 providers (BLE + Wi-Fi), FF1 services, ObjectBox device store.
- Notes: The FFP/DDC block is shown only when the app’s FF1 connection state reports **connected** (`ff1DeviceDataProvider`); when the device is not connected, DeviceConfig does not subscribe to the panel status stream or render FFP/DDC UI. While connected, brightness/contrast/power remain **relayer-driven** (pushed panel snapshots and commands); the surface can stay available during setup and sleeping/off when monitor status exists. The section hides when no relayer monitor status has arrived yet. For monitor **power**, if the relayer omits `power` on a push, the app treats power as unknown, clears optimistic power, and the UI shows **Unknown** with **no** power mode buttons until `power` appears again—so a partial post-power-off snapshot can briefly hide wake/on controls (intentional trade-off: do not offer power actions without relayer-confirmed power). Implementation: `_resolvePendingPower` and `availableFfpMonitorPowerModes` in `ff1_control_surface_providers.dart` / `ffp_monitor_ddc_section.dart`; regression: `ffp_monitor_ddc_section_test.dart` (“incomplete off snapshot”).

### Screen group: NowDisplaying + KeyboardControl

- Purpose: monitor current playback and send interaction commands.
- Entry points: global now-displaying bar (navigates to work detail), `/keyboard-control`.
- Key actions: view current work/device state, open interact mode, send keyboard/touchpad commands.
- Important data: active device, connection state, current item list/index, and enough metadata to keep playback UI usable when enrichment is incomplete.
- Related modules: `now_displaying_provider`, `ff1_wifi_providers`, touchpad/keyboard events.

### Screen group: Settings / Release Notes / Document Viewer

- Purpose: account and app maintenance utilities.
- Entry points: home hamburger menu.
- Key actions: rebuild metadata, forget local data, open EULA/privacy, view release notes.
- Important data: cleanup status overlays, remote markdown/doc content, package version.
- Related modules: local cleanup providers/services, release notes service, remote docs fetch.

## 6. Architecture overview

- Navigation/routing
  - `GoRouter` via `routerProvider`, with typed route constants and guarded payload checks.
  - Deep links are handled by `DeeplinkHandler` (app links + QR path), then routed into app actions.
- Feature/module structure
  - `ui/` screens/widgets
  - `app/` Riverpod providers/notifiers/orchestration
  - `domain/` models and pure helpers
  - `infra/` persistence, network clients, FF1 transport/protocol/control adapters
- State management
  - Riverpod is the single shared state/event flow mechanism.
  - Provider observers/logging enabled; side effects are expected in provider/service layers.
- Networking/backend communication
  - GraphQL indexer via `IndexerClient` + `IndexerService`.
  - Domain resolver GraphQL for ENS/TNS lookups.
  - FF1 relayer WebSocket/REST communication for device state and commands.
  - HTTP fetch for remote config, release notes, legal docs.
- Persistence
  - Drift/SQLite (`dp1_library.sqlite`) for DP-1 channels/playlists/items and searchable read model.
  - ObjectBox for FF1 devices and app/process state (onboarding flags, address indexing anchors/status).
  - Seed DB sync service maintains local SQLite snapshot from S3-compatible source.
- Auth/session
  - No explicit user account login/session flow in current mobile code.
  - App uses API keys from env for service access; address ownership is modeled via indexing, not sign-in sessions.
- Analytics/telemetry
  - Sentry crash/error + GraphQL/DB instrumentation.
  - structured app logging to console/file, support email includes logs/device context.
  - no separate product analytics pipeline is evident in-app today.
- Background/realtime communication
  - FF1 realtime status via relayer transport streams.
  - app lifecycle triggers seed sync and token sync coordination/resume.

## 7. Domain concepts

- Channel
  - DP-1 source of playlists. Includes pinned local-virtual personal "My Collection" channel.
- Playlist
  - Ordered set of works/items. Types include curated DP-1 and address-based personal playlists.
  - Exhibition/Season/Program are playlist roles/UI labels, not separate entities.
- Work
  - User-facing artwork unit represented by `PlaylistItem` with DP-1 core fields and optional token enrichment.
- Address indexing workflow
  - Address -> indexing job workflow -> token ingestion -> personal playlist updates.
- FF1 device
  - Persisted paired device identity (BLE id + topic id + branch info) used for active-device control.
- Now displaying object
  - Derived runtime view of active device + currently playing items/index.

## 8. Key constraints and invariants

- Riverpod remains the single flow driver for shared app/business state and FF1 external events.
- DP-1 vocabulary lock: do not introduce new first-class entities beyond Channel/Playlist/Work.
- Offline-first behavior is required: local DB is primary read path; network enriches/synchronizes.
- FF1 layering must stay separated (`transport` / `protocol` / `control`).
- Deletion-first and no new legacy compatibility by default.
- Bootstrap/seed-gate invariants:
  - **First install:** do not open Drift until `dp1_library.sqlite` exists; keep
    `SeedDatabaseGate` pending until then; lightweight bootstrap must not block
    on `SeedDatabaseGate.future` inside `AppDatabase._openConnection`.
  - **With an existing seed file:** failed sync should not strand users without a
    usable local read path when the file is still valid (see seed sync service).
  - pending addresses added before seed readiness must be migrated post-seed
- Playback/control flows should remain resilient to enrichment failures (fallback item data still usable).
- Now-displaying must remain aligned with live FF1 playback while keeping playback UI usable when enrichment is slow or fails.
- Large flow/screen changes must preserve existing onboarding, address-indexing, and FF1 setup reliability paths.

## 9. Verification strategy

- Test structure
  - unit tests: `test/unit/{app,domain,infra,ui,widgets,...}`
  - integration tests: `test/integration/{app,infra,theme,...}`
- Core commands
  - `flutter pub get`
  - `flutter test`
  - `flutter analyze`
  - `scripts/agent-helpers/post-implementation-checks.sh [--dir DIR] [--all] [git-ref]`
  - `scripts/report_business_coverage.sh`
  - `flutter build apk --flavor development --release`
  - `flutter build apk --flavor production --release`
  - `flutter build ios --release`
- For large feature/flow changes, validate at minimum:
  - onboarding routing and completion state
  - seed DB sync/startup behavior (including resume path)
  - address add/remove/indexing resume behavior
  - FF1 pairing/connectivity and cast/now-displaying behavior
  - no violations of Riverpod/layering/domain vocabulary constraints
