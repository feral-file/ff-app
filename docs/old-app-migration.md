# Old App Migration Notes

This document captures the implemented legacy-data migration behavior from the old app (`~/Documents/projects/feralfile-app`) into this app.

## Goal

Provide a lightweight, one-time migration path for users upgrading from the old app, without blocking startup.

## Implemented Behavior

1. One-time migration guard
- Migration runs only once.
- A local ObjectBox flag is used: `isMigrated`.
 - Stored on `AppStateEntity.isMigrated` in local ObjectBox config state.

2. Legacy onboarded detection
- If a legacy SQLite DB file exists, the user is treated as onboarded.
- App opens Home immediately (skips onboarding route).
- Onboarding seen flag is persisted in current app state.

3. Startup execution model
- Migration starts in background at app startup.
- Toast is shown during migration: `Preparing data...`
- Seed database sync still runs in background.
- Migration is non-blocking for initial navigation.

4. Address migration (legacy Hive -> current storage)
- Reads legacy Hive box `app_storage` keys containing `.common.db.address.`.
- Extracts wallet `address` from stored JSON payloads.
- Extracted addresses are inserted through current `AddressService` with `syncNow: false` (tracked in current data flow, no forced immediate sync burst).

5. FF1 device migration (legacy Hive -> ObjectBox)
- Reads legacy Hive box `app_storage` and keys containing `.common.db.ff_device.`.
- Parses legacy FF1 device JSON payloads and maps to current `FF1Device`.
- Stores devices into ObjectBox through `FF1BluetoothDeviceService`.
- Sets the first migrated device as active.

## Files Added

- `lib/infra/services/legacy_storage_locator.dart`
- `lib/infra/services/legacy_data_migration_service.dart`
- `test/unit/infra/services/legacy_data_migration_service_test.dart`

## Files Updated

- `lib/main.dart`
- `lib/app/app.dart`
- `lib/app/providers/services_provider.dart`
- `pubspec.yaml` (added `hive`)

## Validation Done

- Unit tests for migration guard and success path:
  - `test/unit/infra/services/legacy_data_migration_service_test.dart`
- Post-implementation checks script ran clean (lint/tests for changed scope).
- iOS simulator debug build succeeded.
- Android build could not be executed in current environment (Android SDK missing).
