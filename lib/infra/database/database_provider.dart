import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;
import 'package:objectbox/objectbox.dart';

/// When true, the seed database is ready and DB-watch providers may create
/// streams. When false (during close/replace for Forget I Exist or Rebuild
/// Metadata), providers must not create streams so [close] can complete.
/// Set before [close]; cleared in [rebindDatabaseProviders].
final isSeedDatabaseReadyProvider =
    StateProvider<bool>((ref) => true);

/// Provider for the Drift database instance.
/// Override this in tests with a memory database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Provider for the database service.
/// This is the main entry point for all database operations.
/// Override dependencies in tests using provider overrides.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DatabaseService(db);
});

/// Initialize ObjectBox store for FF1 Bluetooth devices.
/// This must be called during app startup.
///
/// Usage in main.dart:
/// ```dart
/// final store = await ref.read(objectBoxStoreProvider.future);
/// ```
final objectBoxStoreProvider = FutureProvider<Store>((ref) async {
  final store = await initializeObjectBox();
  ref.onDispose(store.close);
  return store;
});

/// Provider for the FF1 Bluetooth device service.
/// Depends on ObjectBox being initialized.
///
/// This provider must be overridden in main.dart after ObjectBox initialization:
/// ```dart
/// final container = ProviderContainer(
///   overrides: [
///     ff1BluetoothDeviceServiceProvider.overrideWithValue(
///       FF1BluetoothDeviceService(store, store.box<FF1BluetoothDeviceEntity>()),
///     ),
///   ],
/// );
/// ```
final ff1BluetoothDeviceServiceProvider = Provider<FF1BluetoothDeviceService>((
  ref,
) {
  throw UnimplementedError(
    'FF1BluetoothDeviceService must be initialized after ObjectBox setup. '
    'Override this provider in ProviderScope with FF1BluetoothDeviceService(store, box).',
  );
});
