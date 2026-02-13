// Reason: small utility methods are self-descriptive.
// ignore_for_file: public_member_api_docs

import 'package:app/infra/database/database_service.dart';

/// Worker-scoped lazy database runtime.
///
/// Drift connection is opened only when [open] is called and closed via
/// [checkpointAndClose] or [close].
class WorkerDatabaseSession {
  WorkerDatabaseSession({
    required Future<DatabaseService> Function() openDatabaseService,
    Future<void> Function(DatabaseService service)? closeDatabaseService,
  }) : _openDatabaseService = openDatabaseService,
       _closeDatabaseService = closeDatabaseService;

  final Future<DatabaseService> Function() _openDatabaseService;
  final Future<void> Function(DatabaseService service)? _closeDatabaseService;
  DatabaseService? _databaseService;

  bool get isOpen => _databaseService != null;

  Future<void> open() async {
    if (_databaseService != null) {
      return;
    }
    _databaseService = await _openDatabaseService();
  }

  DatabaseService get databaseService {
    final service = _databaseService;
    if (service == null) {
      throw StateError('Worker database session is closed. Call open() first.');
    }
    return service;
  }

  Future<void> checkpointAndClose() async {
    final service = _databaseService;
    if (service != null) {
      await service.checkpoint();
    }
    await close();
  }

  Future<void> close() async {
    final service = _databaseService;
    _databaseService = null;
    if (service != null && _closeDatabaseService != null) {
      await _closeDatabaseService(service);
    }
  }
}
