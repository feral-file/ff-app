import 'package:app/app/app.dart';
import 'package:app/app/providers/app_provider_observer.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/legacy_storage_locator.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Shared app bootstrap state used by both production startup and Patrol tests.
class AppBootstrapResult {
  /// Creates an [AppBootstrapResult].
  const AppBootstrapResult({
    required this.bluetoothDeviceService,
    required this.appStateService,
    required this.hasDoneOnboarding,
    required this.hasLegacySqliteDatabase,
    required this.initialLocation,
  });

  /// ObjectBox-backed FF1 persistence service used by Riverpod providers.
  final FF1BluetoothDeviceService bluetoothDeviceService;

  /// ObjectBox-backed app state service.
  final AppStateService appStateService;

  /// Whether onboarding should be skipped on startup.
  final bool hasDoneOnboarding;

  /// Whether legacy storage was detected during bootstrap.
  final bool hasLegacySqliteDatabase;

  /// Initial route for the root app router.
  final String initialLocation;
}

final _log = Logger('AppBootstrap');

/// Initializes shared startup dependencies and resolves the initial route.
Future<AppBootstrapResult> bootstrapAppDependencies() async {
  final store = await initializeObjectBox();
  final bluetoothDeviceService = FF1BluetoothDeviceService(
    store.box<FF1BluetoothDeviceEntity>(),
  );
  final appStateService = AppStateService(
    store: store,
    appStateBox: store.box<AppStateEntity>(),
    appStateAddressBox: store.box<AppStateAddressEntity>(),
    trackedAddressBox: store.box<TrackedAddressEntity>(),
  );

  final legacyStorageLocator = LegacyStorageLocator();
  final hasLegacySqliteDatabase = await legacyStorageLocator
      .hasLegacySqliteDatabase();

  final tempContainer = ProviderContainer();
  var hasDoneOnboarding = await tempContainer.read(
    hasDoneOnboardingProvider.future,
  );
  tempContainer.dispose();

  if (!hasDoneOnboarding && hasLegacySqliteDatabase) {
    await appStateService.setHasSeenOnboarding(hasSeen: true);
    hasDoneOnboarding = true;
  }

  // Recover from a mid-swap crash: canonical file missing but staged/backup
  // swap artifacts may still be present (see seed replace recoverable swap).
  final seedDatabaseService = SeedDatabaseService();
  await runSeedRepairAndCompleteGateIfUsable(seedDatabaseService);

  final initialLocation = hasDoneOnboarding || hasLegacySqliteDatabase
      ? Routes.home
      : Routes.onboardingIntroducePage;

  return AppBootstrapResult(
    bluetoothDeviceService: bluetoothDeviceService,
    appStateService: appStateService,
    hasDoneOnboarding: hasDoneOnboarding,
    hasLegacySqliteDatabase: hasLegacySqliteDatabase,
    initialLocation: initialLocation,
  );
}

/// Same ordering as [bootstrapAppDependencies]: repair interrupted swap, then
/// open the seed gate when the local DB validates. Kept testable so startup
/// repair + gate behavior stays covered without full ObjectBox bootstrap.
@visibleForTesting
Future<void> runSeedRepairAndCompleteGateIfUsable(
  SeedDatabaseService seedDatabaseService,
) async {
  try {
    await seedDatabaseService.repairInterruptedSeedSwapIfNeeded();
  } on Object catch (e, st) {
    _log.warning(
      'Seed swap startup repair failed; continuing without blocking startup.',
      e,
      st,
    );
  }

  await completeSeedDatabaseGateIfUsable(seedDatabaseService);
}

/// Opens [SeedDatabaseGate] only when the local seed database is valid.
@visibleForTesting
Future<void> completeSeedDatabaseGateIfUsable(
  SeedDatabaseService seedDatabaseService,
) async {
  if (await seedDatabaseService.isResetCleanupInProgress()) {
    // Never clear the marker here just because the DB still validates. A crash
    // after [markResetCleanupInProgress] but before
    // [deleteDatabaseFiles] leaves both marker and a usable DB; clearing would
    // reopen pre-wipe data (privacy risk). Stale markers without swap residue
    // are handled in [SeedDatabaseService.repairInterruptedSeedSwapIfNeeded].
    _log.info(
      'Skipping seed gate completion while reset cleanup is in progress.',
    );
    return;
  }
  if (await seedDatabaseService.hasUsableLocalDatabase()) {
    SeedDatabaseGate.complete();
  }
}

/// Builds the production app root with the resolved bootstrap state.
Widget buildBootstrapApp({
  required AppBootstrapResult bootstrap,
}) {
  return ProviderScope(
    observers: [AppProviderObserver()],
    overrides: [
      ff1BluetoothDeviceServiceProvider.overrideWithValue(
        bootstrap.bluetoothDeviceService,
      ),
    ],
    child: App(initialLocation: bootstrap.initialLocation),
  );
}

/// Attaches post-onboarding Sentry context when available.
Future<void> attachPostOnboardingSentryContext({
  required bool hasDoneOnboarding,
  required AppStateService appStateService,
  required FF1BluetoothDeviceService bluetoothDeviceService,
}) async {
  if (!hasDoneOnboarding || !Sentry.isEnabled) {
    return;
  }

  try {
    final addedAddresses = await appStateService.getTrackedPersonalAddresses();
    final ff1DeviceIds =
        bluetoothDeviceService
            .getAllDevices()
            .map((device) => device.deviceId.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Sentry.configureScope((scope) async {
      await scope.setContexts('post_onboarding_state', {
        'added_addresses': addedAddresses,
        'ff1_device_ids': ff1DeviceIds,
      });
    });
  } on Object catch (error, stackTrace) {
    _log.warning(
      'Failed to attach post-onboarding Sentry context',
      error,
      stackTrace,
    );
  }
}
