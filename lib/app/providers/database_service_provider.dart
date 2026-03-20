import 'dart:async';

import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Re-exports for consumers that need direct access (e.g. close flow, tests).
export 'package:app/infra/database/database_provider.dart'
    show appDatabaseProvider, rawDatabaseServiceProvider;

/// Readiness-aware database service.
///
/// Single boundary for all DB access. When [isSeedDatabaseReadyProvider] is
/// false (during Forget I Exist / rebuildMetadata), returns a DatabaseService
/// backed by an empty in-memory DB so no new subscriptions attach to the real
/// DB. When ready, delegates to [rawDatabaseServiceProvider].
///
/// Consumers that attach long-lived DB streams must also [ref.watch] this
/// provider (not only [ref.read]) so invalidation tears down subscriptions.
/// [LocalDataCleanupService] still uses an explicit invalidation list because
/// [ref.read] does not register a dependency.
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final isReady = ref.watch(isSeedDatabaseReadyProvider);
  if (!isReady) {
    return ref.read(_emptyDatabaseServiceProvider);
  }
  return ref.read(rawDatabaseServiceProvider);
});

/// Empty in-memory DatabaseService for the not-ready window.
/// Prevents new DB subscriptions while reset flows drain and close the real DB.
final _emptyDatabaseServiceProvider = Provider<DatabaseService>((ref) {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  ref.onDispose(() => unawaited(db.close()));
  return DatabaseService(db);
});
