// Reason: service methods are straightforward wrappers around worker calls.
// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/index_single_address_worker.dart';
import 'package:logging/logging.dart';

/// Service that isolates address indexing trigger + workflow polling.
class IndexerAddressIndexingService {
  IndexerAddressIndexingService({
    required IndexSingleAddressWorker worker,
    Logger? logger,
  }) : _worker = worker,
       _log = logger ?? Logger('IndexerAddressIndexingService');

  final IndexSingleAddressWorker _worker;
  final Logger _log;

  Future<void> ensureAddressIndexed(String address) async {
    final normalized = address.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('address must not be empty');
    }

    if (_worker.state != BackgroundWorkerState.started) {
      await _worker.start();
    }

    try {
      await _worker.enqueueAddress(normalized);
    } on Object catch (e, stack) {
      _log.warning('Failed to ensure indexed address: $normalized', e, stack);
      rethrow;
    }
  }

  Future<void> pause() => _worker.pause();

  Future<void> stop() => _worker.stop();

  Future<void> dispose() async {
    await _worker.stop();
  }
}
