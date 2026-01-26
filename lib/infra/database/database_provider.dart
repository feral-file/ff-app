import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';
import 'database_service.dart';

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
