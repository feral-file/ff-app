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
  - run app bootstrap sequence (force-update check, seed sync, legacy migration, bootstrap service, pending address migration, indexing resume)
- success state: user lands on `/` or onboarding route with DB/services ready
- failure/edge states:
  - invalid env config shows blocking configuration error screen
  - seed sync failure falls back to existing/local DB and still unblocks app
  - legacy migration errors are logged and do not block startup
- key screens involved: config error screen (fallback), Home, Onboarding
- key modules/services involved: `lib/main.dart`, `lib/app/app.dart`, `seed_database_*`, `bootstrap_provider`, `legacy_data_migration_service`, `app_state_service`

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
  - if seed DB not yet ready, addresses are queued and migrated later
  - address validation failures are inline and non-fatal
- key screens involved: Introduce, Onboarding Add Address, Onboarding Setup FF1
- key modules/services involved: `onboarding_provider`, `add_address_provider`, `address_service`, `pending_addresses_store`

## Flow: Onboarding from Device Deeplink/QR
- goal: continue onboarding while preserving FF1 connect intent
- start point: deeplink or scan action resolves to device connect
- steps:
  - deeplink handler emits device-connect action
  - app routes to start-setup/connect path
  - if onboarding not completed, onboarding pages run with deeplink payload
  - after onboarding add-address step, flow returns to connect FF1 page
- success state: user completes onboarding and continues device setup path
- failure/edge states:
  - unsupported deep links are ignored safely
  - repeated handling of same link is deduplicated
- key screens involved: Start Setup FF1, Introduce, Onboarding Add Address, Connect FF1
- key modules/services involved: `deeplink_handler`, `router_provider`, onboarding providers

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
  - user opens Now Displaying full screen and optional keyboard/touchpad Interact screen
- success state: active playback visible and controllable from app
- failure/edge states:
  - no paired device -> guidance state
  - disconnected device -> disconnected state
  - enrichment/cache misses fall back to basic DP-1 item fields
- key screens involved: Work Detail, Playlist Detail, Now Displaying, Keyboard Control
- key modules/services involved: `canvas_client_service_v2`, `now_displaying_provider`, `ff1_wifi_providers`, `ff1_device_provider`

## Flow: Settings Recovery and Support
- goal: maintain app health, recover local state, and contact support
- start point: Settings and menu actions
- steps:
  - rebuild metadata (clear/recreate DB from seed and refetch)
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
- notes / caveats: duplicate and invalid-input errors are explicit and distinct

## Screen: AddAliasScreen
- role in the flow: optional naming before persisting a raw address
- route / entry point: `/add-alias` (requires payload)
- important actions: submit alias or skip
- dependencies: `addAliasProvider`, `addressService`
- notes / caveats: successful completion pops both alias and add-address routes

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

## Screen: FF1DevicePickerPage
- role in the flow: BLE discovery and initial FF1 selection
- route / entry point: `/ff1-device-picker`
- important actions: start scan, retry scan, select device
- dependencies: `bluetoothAdapterStateProvider`, `ff1ScanProvider`
- notes / caveats: auto-navigates when exactly one device found after scan completes

## Screen: ConnectFF1Page
- role in the flow: BLE connection progress, post-connect routing, and error handling
- route / entry point: `/connect-ff1` (requires payload)
- important actions: cancel/retry, continue to device config or Wi-Fi flow
- dependencies: `connectFF1Provider`, onboarding actions, FF1 device persistence providers
- notes / caveats: transitions to "still connecting" after 15 seconds

## Screen: ScanWiFiNetworkScreen + EnterWiFiPasswordScreen
- role in the flow: Wi-Fi provisioning when FF1 is not internet-ready
- route / entry point: `/scan-wifi-networks` and `/enter-wifi-password`
- important actions: retry scan, choose/manual SSID, submit password, finalize
- dependencies: `connectWiFiProvider`, FF1 BLE command providers, support dialog helpers
- notes / caveats: open networks auto-submit without password

## Screen: DeviceConfigScreen
- role in the flow: post-pairing control surface for orientation/scaling/audio/device info
- route / entry point: `/device-configuration`
- important actions: adjust display settings, switch device/options, finish setup flow
- dependencies: active FF1 provider, `ff1DeviceDataProvider`, FF1 Wi-Fi control
- notes / caveats: setup mode hides some advanced sections until post-setup use

## Screen: NowDisplayingScreen
- role in the flow: full-screen playback status and quick interaction launch
- route / entry point: `/now-displaying`
- important actions: open Interact, open FF1 settings quick sheet
- dependencies: `nowDisplayingProvider`, now-displaying quick settings widgets
- notes / caveats: route is intentionally hidden from global now-displaying bar duplication logic

## Screen: KeyboardControlScreen
- role in the flow: send keyboard/touchpad events to currently connected FF1
- route / entry point: `/keyboard-control`
- important actions: type keys, use touchpad
- dependencies: now-displaying success state, `ff1WifiControlProvider`
- notes / caveats: exits when keyboard closes and screen is not expanded

## Screen: SettingsPage
- role in the flow: account/data maintenance entrypoint
- route / entry point: `/settings`
- important actions: rebuild metadata, forget I exist, open legal docs
- dependencies: local cleanup provider, app overlay, package info provider
- notes / caveats: "Forget I exist" always routes back to onboarding after cleanup attempt
