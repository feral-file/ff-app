import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:objectbox/objectbox.dart';

import 'app_database.dart';
import 'database_service.dart';
import 'ff1_bluetooth_device_service.dart';
import 'objectbox_init.dart';
import 'objectbox_models.dart';

/// Provider for the Drift database instance.
/// Override this in tests with a memory database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
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
  ref.onDispose(() => store.close());
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
///       FF1BluetoothDeviceService(box),
///     ),
///   ],
/// );
/// ```
final ff1BluetoothDeviceServiceProvider = 
    Provider<FF1BluetoothDeviceService>((ref) {
  throw UnimplementedError(
    'FF1BluetoothDeviceService must be initialized after ObjectBox setup. '
    'Override this provider in ProviderScope with FF1BluetoothDeviceService(box).',
  );
});
