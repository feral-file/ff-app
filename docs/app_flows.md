# App Flows

## Document contract

- This document is the execution-level companion to `docs/project_spec.md`.
- It describes how the product contract is implemented through routes,
  providers, services, and screen transitions.
- It must not redefine domain vocabulary or product invariants.
- If this file diverges from `docs/project_spec.md`, treat it as outdated and
  update it to match the spec.

## Flow: Cold Start Bootstrap

- goal: start app into a usable state with local data and providers initialized
- start point: app process launch (`main()`)
- steps:
  - load env config, initialize logging and optional Sentry
  - determine initial route from onboarding state + legacy DB detection
  - initialize ObjectBox services and provider overrides
  - run app bootstrap sequence (force-update check, seed sync, legacy migration, bootstrap service, ensureTrackedAddressesHavePlaylistsAndResume when the seed file and gate allow DB work)
- success state: user lands on `/` or onboarding route with DB/services ready
- failure/edge states:
  - invalid env config shows blocking configuration error screen
  - **First install (no `dp1_library.sqlite`):** seed sync may fail or skip
    (e.g. offline); `SeedDatabaseGate` stays pending; app runs lightweight
    bootstrap only (no Drift open) so onboarding/home can load; tabs show
    retryable feed-blocking UI until download succeeds; full DP-1 bootstrap and
    tracked-address resume run after a later successful seed (including
    `pendingDp1BootstrapAfterSeed` completion).
  - **Existing seed file:** failed sync typically keeps using the on-disk library;
    app still unblocks when the local DB remains valid.
  - legacy migration errors are logged and do not block startup
- startup UX contract:
  - when onboarding is incomplete, seed-sync UI is background-only (no startup
    "Updating art library" toast / no seed loading indicator state), while sync
    and gate behavior still run normally
- key screens involved: config error screen (fallback), Home, Onboarding
- key modules/services involved: `lib/main.dart`, `lib/app/app.dart`, `seed_database_*`, `bootstrap_provider`, `legacy_data_migration_service`, `app_state_service`

## Flow: App lifecycle and FF1 relayer Wi‑Fi

- goal: pause the FF1 relayer WebSocket when the app is not active, without tearing it down on every transient `inactive`, and restore it after real backgrounding
- start point: `AppLifecycleNotifier` (`app_lifecycle_provider.dart`) handling `WidgetsBindingObserver` lifecycle updates
- steps:
  - `inactive`: schedule a debounced relayer pause; `resumed` cancels only the pending timer (no reconnect if the relayer was never paused)
  - `paused` / `hidden` / `detached`: cancel any debounce and pause relayer Wi‑Fi immediately
  - `resumed`: resume indexer token sync; call `FF1WifiConnectionNotifier.reconnect` only when lifecycle actually paused the relayer in this cycle (immediate pause or debounced inactive pause)
  - the first successful relayer session for a device triggers the required-device-version check, including the later resume reconnect path after a suppressed initial connect
- success state: relayer socket matches whether the app backgrounded; short inactive-only flicker does not force reconnect
- failure/edge states: reconnect failures are logged; connection notifier clears stale connecting flags when pause races with an in-flight connect
- key modules: `app_lifecycle_provider.dart`, `inactive_wifi_pause_schedule.dart`, `ff1_wifi_providers.dart` (`FF1WifiConnectionNotifier`)

## Flow: Onboarding (No Deeplink)

- goal: orient new users and optionally set up personal collection + FF1
- start point: `/onboarding/introduce`
- steps:
  - Introduce page -> Onboarding Add Address page
  - user can add/remove addresses or skip
  - continue to onboarding FF1 setup page
  - user can open FF1 setup or finish onboarding directly
- success state: onboarding completion flag persisted, user routed to `/`
- failure/edge states:
  - address validation failures are inline and non-fatal
  - while startup seed sync is still running, the add-address onboarding step
    disables its primary/secondary actions and shows a waiting message instead
    of racing bootstrap state changes
  - after first-install lightweight bootstrap (`deferredRecovery`), onboarding
    address adds re-open and queue until a later successful seed download
- key screens involved: Introduce, Onboarding Add Address, Onboarding Setup FF1
- key modules/services involved: `onboarding_provider`, `add_address_provider`, `address_service`, `trackedAddressesSyncProvider`
- notes: TrackedAddressEntity (ObjectBox) is the single source of truth for user-added addresses; `trackedAddressesSyncProvider` watches it and ensures playlists exist + indexing resumes

## Flow: Onboarding from Device Deeplink/QR

- goal: continue onboarding while preserving FF1 connect intent
- start point: deeplink or scan action resolves to device connect
- steps:
  - deeplink handler emits device-connect action
  - if onboarding not completed, app routes to introduce page with deeplink payload
  - after onboarding add-address step, flow navigates to FF1 Device Scan page
  - FF1 Device Scan page scans for the specific device (from deeplink name)
  - when device is found, custom callback navigates to Connect FF1 page
- success state: user completes onboarding and continues device setup path
- failure/edge states:
  - unsupported deep links are ignored safely
  - repeated handling of same link is deduplicated
  - if device not found during scan, user sees empty scan result
- key screens involved: Start Setup FF1, Introduce, Onboarding Add Address, FF1 Device Scan, Connect FF1
- key modules/services involved: `deeplink_handler`, `router_provider`, onboarding providers, `ff1_scan_provider`

## Flow: Address Add and Personal Collection Sync

- goal: create/update personal address playlist and begin token ingestion
- start point: Add Address screen (home menu or onboarding)
- steps:
  - user enters address/ENS/TNS or scans QR
  - app verifies domain/address and checks duplicates
  - if raw address, alias screen is shown; if domain, address may be added directly
  - address service stores playlist/tracked state and schedules indexing/sync
- success state: address-based playlist appears under personal playlists with indexed items over time
- failure/edge states:
  - duplicate address blocked with specific message
  - invalid address/domain blocked with specific message
  - indexing workflow resumes after app restarts via persisted app state
- key screens involved: Add Address, Add Alias, Playlist screens (Me)
- key modules/services involved: `add_address_provider`, `address_service`, `domain_address_service`, `indexer_service_isolate`, `personal_tokens_sync_service`

## Flow: Browse Content and Open Details

- goal: navigate DP-1 content quickly from home tabs to detail pages
- start point: Home Index (`/`)
- steps:
  - user browses Playlists/Channels/Works tabs
  - optionally opens full list pages for curated/personal groups
  - opens channel/playlist/work detail routes
  - can refresh/retry on loading errors
- success state: user reaches detailed content view and related actions
- failure/edge states:
  - seed syncing/error states block normal tab content until resolved/retried
  - empty states shown for missing content
- key screens involved: Home, All Channels, All Playlists, Channel Detail, Playlist Detail, Work Detail
- key modules/services involved: `channels_provider`, `playlists_provider`, `works_provider`, DB service
- notes (All Channels):
  - `/channels/all` groups curated channels by publisher with publisher names as section headers; the order within each publisher section stays the same as the loaded list
  - personal channels remain flat
- notes (All Playlists):
  - non–channel-scoped “View all” / All Playlists lists **group by publisher**
    (section headers from publisher titles) when the seed DB is ready, publisher
    and channel lookup streams have settled, and more than one publisher section
    applies; otherwise the list stays **flat** (including a single publisher
    bucket)
  - **channel-scoped** All Playlists (filtered to one or more channel IDs) stays
    **flat** and does not subscribe to full-table publisher/channel lookup
    streams

## Flow: Search and Filter

- goal: find channels/playlists/works from local library model
- start point: Search action from Home header
- steps:
  - user types query, suggestions appear from debounced input
  - user submits query, sees aggregated results
  - user applies filter type/source/date and sort order
  - tapping result routes to corresponding detail screen
- success state: user opens relevant result detail
- failure/edge states:
  - empty and error states provide fallback guidance/support entry
  - short/stale queries are ignored to reduce churn
- key screens involved: Search screen + detail screens
- key modules/services involved: `search_provider`, DB search methods, filter helper modules

## Flow: FF1 Pairing and Wi-Fi Setup

- goal: pair FF1 and establish usable connectivity for control/playback
- start point: FF1 Device Picker, Start Setup FF1, or deeplink route
- steps:
  - BLE scan and selection (or deeplink-based lookup)
  - connect over BLE and fetch device info
  - if FF1 not internet-connected/topic missing, run Wi-Fi network scan + credential flow
  - persist device and set active
  - navigate to Device Configuration
- success state: active FF1 exists with usable topic ID (or post-connect setup path)
- failure/edge states:
  - BLE/network errors route to retry/cancel/support paths
  - device-updating/version-check errors trigger dedicated dialogs/routes
- key screens involved: FF1 Device Picker, Start Setup FF1, Connect FF1, Scan WiFi, Enter WiFi Password, Device Config
- key modules/services involved: `ff1_providers`, `connect_ff1_providers`, `connect_wifi_provider`, `ff1_bluetooth_device_providers`, `ff1_wifi_control`

## Flow: Cast and Now Displaying Control

- goal: play selected work/playlist on active FF1 and expose real-time control
- start point: Work Detail or Playlist Detail play action
- steps:
  - build DP-1 payload and cast via canvas client to selected device
  - now-displaying state derives from active device + relayer player/device streams
  - now-displaying bar displays current item and appears as floating overlay
  - for the visible index window, the app reads matching rows from local SQLite to avoid redundant enrichment, then may call the indexer only for items still missing after that read; live DP-1 fields from the device fill gaps and cover enrichment failures, and same-playlist window changes (index shifts or scroll expansion) update immediately with DP-1 fallback rows while enrichment catches up
  - user taps bar to navigate to current work detail (or already there)
  - collapsed now-playing row: shuffle and repeat are shown only when the live `player_status` includes the corresponding capability—shuffle when the `shuffle` key is present, repeat when `loopMode` parses to a known value (`none`, `playlist`, `one`); the two gates are independent so a future unknown `loopMode` string does not drop the whole status parse and does not suppress shuffle
  - when the playing list has only one work (length from `player_status.items` when present, else the visible now-displaying item window), shuffle and repeat controls are not shown
  - optional: user opens Interact screen for keyboard input and touchpad
    gesture control
- success state: active playback visible and controllable from app
- failure/edge states:
  - no paired device -> bar hidden (invisible, no guidance shown)
  - disconnected device -> bar shows disconnected state
  - enrichment/cache misses fall back to basic DP-1 item fields
  - loading overlay only when playlist id or item list from FF1 changes; pause/sleep or index nudges that keep the same visible index window reuse rows without flashing loading; if the index moves enough to shift the window on a long playlist, or the user expands the range, the app updates immediately with DP-1 fallback rows and enriches that new slice in the background without a loading flash
  - expanded-bar scroll expansion is scoped to the current playing list: switching playlist or ordered items clears the widened range so the next window is not inflated by a previous session
- key screens involved: Work Detail, Playlist Detail, Keyboard Control, Now Displaying Bar (overlay)
- key modules/services involved: `canvas_client_service_v2`, `now_displaying_provider`, `ff1_wifi_providers`, `ff1_device_provider`
- notes: The quick DDC brightness/contrast controls shown in Now Displaying reuse the same shared zero-toggle helper as DeviceConfig, so icon taps jump to `0` and restore the previous non-zero value while slider drags still commit the final level normally. End-to-end repeat-off requires FF1 firmware that accepts `setLoop` with `mode: none` and echoes `loopMode: none` in `player_status`; the app tolerates unknown `loopMode` strings when parsing `player_status` for forward compatibility.

## Flow: Settings Recovery and Support

- goal: maintain app health, recover local state, and contact support
- start point: Settings and menu actions
- steps:
  - rebuild metadata (download seed, then replace DB on disk; refetch)
  - forget I exist (clear local data, reset onboarding)
  - open release notes, legal docs, support email
- success state: user gets clean local state or support path as needed
- failure/edge states:
  - cleanup failures still route to onboarding reset path
  - release notes/docs failures show user-facing unavailable messages
- key screens involved: Settings, Forget I Exist dialog, Release Notes, Document Viewer
- key modules/services involved: `local_data_cleanup_service`, `release_notes_service`, `support_email_service`, `force_update_service`

## Screen: HomeIndexPage

- role in the flow: central browsing surface and menu launcher
- route / entry point: `/`
- important actions: switch tabs, open search/menu utilities, open add-address, open FF1 settings
- dependencies: tab providers, seed download state, active FF1 provider
- notes / caveats: default selected tab is Playlists in current implementation

## Screen: AddAddressScreen

- role in the flow: intake and validation for wallet/domain add flow
- route / entry point: `/add-address`
- important actions: submit input, scan QR, continue to alias or complete
- dependencies: `addAddressFlowProvider`, `scanQrProvider`, address/domain services
- notes / caveats: duplicate and invalid-input errors are explicit and distinct; focus and post-frame work use `scheduleRequestFocusWhenLaidOut` / `schedulePostFrameIfMounted` so navigation after layout does not assert on disposed `BuildContext`

## Screen: AddAliasScreen

- role in the flow: optional naming before persisting a raw address
- route / entry point: `/add-alias` (requires payload)
- important actions: submit alias or skip
- dependencies: `addAliasProvider`, `addressService`
- notes / caveats: successful completion pops both alias and add-address routes; same deferred focus / post-frame helpers as Add Address when requesting focus after route transitions

## Screen: PlaylistDetailScreen

- role in the flow: playlist-level metadata, work grid, and play action
- route / entry point: `/playlists/:playlistId`
- important actions: cast playlist to FF1, open work detail, delete personal playlist/address
- dependencies: playlist/channel providers, DB service, canvas client, address service
- notes / caveats: personal playlists show collection-state header with retry indexing

## Screen: WorkDetailScreen

- role in the flow: work-level media preview and metadata/provenance view
- route / entry point: `/works/:workId`
- important actions: cast single work, open external market links, rebuild work metadata
- dependencies: `workDetailStateProvider`, indexer/DB enrichment, canvas client
- notes / caveats: token enrichment is optional; UI supports item-only fallback

## Screen: FF1DeviceScanPage

- role in the flow: BLE discovery and initial FF1 selection
- route / entry point: `/ff1-device-scan` (optional `extra`: `FF1DeviceScanPagePayload` with `String? ff1Name` and optional `onFF1Selected` to override default navigation after selection)
- important actions: start scan, retry scan, select device
- dependencies: `bluetoothAdapterStateProvider`, `ff1ScanProvider`
- notes / caveats: when `ff1Name` is null, lists all discovered FF1 devices and does not auto-advance; user must pick one. When `ff1Name` is set, `startScan` uses name-targeted discovery; if exactly one device is returned after the scan, the app auto-advances to start setup (same as choosing that device) and shows a short “continuing setup” state instead of the picker list

## Screen: ConnectFF1Page

- role in the flow: BLE connection progress, post-connect routing, and error handling
- route / entry point: `/connect-ff1` (requires `ConnectFF1PagePayload` with `device` and optional `ff1DeviceInfo`)
- important actions: cancel/retry, continue to device config or Wi-Fi flow
- dependencies: `connectFF1Provider`, onboarding actions, FF1 device persistence providers
- notes / caveats:
  - transitions to "still connecting" after 15 seconds
  - When `ff1DeviceInfo` is provided (from deeplink), skips get_info command and uses supplied metadata
  - **Navigation contract**: FF1 setup side effects (device persistence, onboarding completion, Wi-Fi QR hide) are owned by the FF1 setup orchestration layer. When the device is internet-ready, the flow navigates to device configuration. When the device is not internet-ready, the flow routes into the Wi-Fi provisioning steps.

## Screen: ScanWiFiNetworkScreen + EnterWiFiPasswordScreen

- role in the flow: Wi-Fi provisioning when FF1 is not internet-ready
- route / entry point: `/scan-wifi-networks` and `/enter-wifi-password`
- important actions: retry scan, choose/manual SSID, submit password, finalize
- dependencies: `connectWiFiProvider`, FF1 BLE command providers, support dialog helpers
- notes / caveats: open networks auto-submit without password

## Screen: DeviceConfigScreen

- role in the flow: post-pairing control surface for orientation/scaling/audio (FF1), FFP/DDC display brightness/contrast/power, device info, and post-setup firmware update entry/prompt orchestration
- route / entry point: `/device-configuration`
- important actions: adjust display settings, DDC brightness/contrast/power, switch device/options, finish setup flow, start **Update FF1**
- dependencies: active FF1 provider, `ff1DeviceDataProvider`, FF1 Wi-Fi control
- notes / caveats:
  - setup mode hides advanced sections and suppresses the firmware auto-prompt
    during the initial setup visit
  - pairing-QR toggle contract: Device Configuration decides whether to render
    the Show/Hide Pairing QR action from FF1 status signals (for example parsed
    `displayURL` pairing step when present), while setup orchestration may hide
    this action before entering Device Configuration. This contract governs
    control visibility, not the setup-path initial local toggle value.
  - FFP/DDC UI is gated on **device connected** (same `ff1DeviceData` connection flag as the rest of DeviceConfig): when not connected, the screen does not watch `ff1FfpDdcPanelStatusStreamProvider` or show the FFP/DDC section. While connected, controls are driven by relayer-pushed status updates and can stay available during setup and sleeping/off when the display exposes DDC; there is no in-app monitor volume or mute. Brightness/contrast icon taps use the shared zero-toggle helper: tap once to jump to `0`, tap again from `0` to restore the last non-zero value. The section hides when no relayer status has arrived.
  - **Monitor power (DDC):** Optimistic power is cleared when the relayer omits `power` on a status push, so the effective value becomes unknown. The UI then shows **Unknown** and **no** power mode actions (`availableFfpMonitorPowerModes` is empty for null) until a later push includes `power` again. **Why this is OK:** After FFP power-off, many monitors do not support reading power status over DDC, so the relayer often sends DDC notifications **without** `power`. The app must not guess On/Standby/Off in that case. **Reviewer note:** Unknown with no power buttons when `power` is absent is **specified, accepted behavior**—not a bug. Do not request wake/on controls or inferred power while `power` is null unless product requirements change. Code: `FF1FfpDdcControlNotifier` / `_resolvePendingPower`; widget tests: `test/unit/widgets/ffp_monitor_ddc_section_test.dart`.
  - manual **Update FF1** appears only after relayer connectivity plus both
    `installedVersion` and `latestVersion` are available; the auto-prompt can
    still appear earlier once relayer/version fields are present
  - manual **Update FF1** and the auto-prompt both start the same relayer-only
    firmware update path; the app does not start FF1 firmware updates over BLE
  - firmware update eligibility is re-checked when active device, relayer
    connection, or reported version fields change, so a late relayer
    connection can still surface the prompt
  - the auto-prompt only appears while Device Configuration is the visible
    route; relayer updates that arrive while another route covers the screen
    must wait until the user returns
  - prompt/session dedupe allows only one in-flight firmware prompt at a time;
    if the device later reports a different `latestVersion` during the same
    visit, the screen may prompt again for that newer build
  - both the auto-prompt and the manual options entry persist the accepted or
    dismissed `latestVersion` for that device so the same build is not shown
    again while OTA install status is catching up

## Screen: KeyboardControlScreen

- role in the flow: send keyboard input and touchpad gesture events to the
  currently connected FF1
- route / entry point: `/keyboard-control`
- important actions: type keys, use touchpad gestures
- dependencies: now-displaying success state, `ff1WifiControlProvider`
- notes / caveats: exits when keyboard closes and screen is not expanded; the
  touchpad forwards single tap, double tap, long press, move-only drag,
  click-and-drag, and pinch zoom gestures through `TouchPad` /
  `FfMouseGestureDetector`, batching deltas before they are sent to FF1

## Screen: SettingsPage

- role in the flow: account/data maintenance entrypoint
- route / entry point: `/settings`
- important actions: rebuild metadata, forget I exist, open legal docs
- dependencies: local cleanup provider, app overlay, package info provider
- notes / caveats: "Forget I exist" always routes back to onboarding after cleanup attempt
