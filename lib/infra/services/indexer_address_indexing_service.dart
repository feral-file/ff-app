import 'dart:async';

import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/indexer/isolate/address_indexing_worker.dart';
import 'package:logging/logging.dart';

/// Service that isolates address indexing trigger + workflow polling.
class IndexerAddressIndexingService {
  IndexerAddressIndexingService({
    AddressIndexingWorker? worker,
    Logger? logger,
  }) : _worker =
           worker ??
           AddressIndexingWorker(
             endpoint: AppConfig.indexerApiUrl,
             apiKey: AppConfig.indexerApiKey,
           ),
       _log = logger ?? Logger('IndexerAddressIndexingService');

  final AddressIndexingWorker _worker;
  final Logger _log;

  bool _started = false;

  Future<void> ensureAddressIndexed(String address) async {
    final normalized = address.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('address must not be empty');
    }

    if (!_started) {
      await _worker.start();
      _started = true;
    }

    try {
      await _worker.ensureIndexed(address: normalized);
    } on Object catch (e, stack) {
      _log.warning('Failed to ensure indexed address: $normalized', e, stack);
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (!_started) {
      return;
    }
    await _worker.stop();
    _started = false;
  }
}
