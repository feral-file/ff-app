// Reason: worker constructor/entrypoints are intentionally compact.
// ignore_for_file: public_member_api_docs, use_super_parameters

import 'dart:collection';

import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/indexer/isolate/address_indexing_worker.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:logging/logging.dart';

/// Worker that indexes one address at a time with checkpointable queue state.
class IndexSingleAddressWorker extends BackgroundWorker {
  IndexSingleAddressWorker({
    required WorkerStateStore workerStateService,
    AddressIndexingWorker? worker,
    Logger? logger,
  }) : _worker =
           worker ??
           AddressIndexingWorker(
             endpoint: AppConfig.indexerApiUrl,
             apiKey: AppConfig.indexerApiKey,
           ),
       _log = logger ?? Logger('IndexSingleAddressWorker'),
       super(
         workerId: _workerId,
         workerStateService: workerStateService,
         logger: logger,
       );

  static const String _workerId = 'index_single_address_worker';

  final AddressIndexingWorker _worker;
  final Logger _log;

  final Queue<String> _pendingAddresses = Queue<String>();
  bool _isDraining = false;
  String? _inFlightAddress;

  @override
  bool get hasRemainingWork =>
      _pendingAddresses.isNotEmpty || _inFlightAddress != null;

  Future<void> enqueueAddress(String address) async {
    final normalized = address.trim();
    if (normalized.isEmpty) {
      return;
    }

    final alreadyQueued = _pendingAddresses.contains(normalized);
    if (_inFlightAddress == normalized || alreadyQueued) {
      return;
    }

    _pendingAddresses.add(normalized);
    await checkpoint();
    if (state == BackgroundWorkerState.started) {
      await _drainQueue();
    }
  }

  @override
  Future<void> onStart() async {
    await _worker.start();
    await _drainQueue();
  }

  @override
  Future<void> onPause() async {
    final inFlight = _inFlightAddress;
    if (inFlight != null && !_pendingAddresses.contains(inFlight)) {
      _pendingAddresses.addFirst(inFlight);
      _inFlightAddress = null;
    }
    await _worker.stop();
  }

  @override
  Future<void> onStop() async {
    await _worker.stop();
  }

  @override
  Future<Map<String, dynamic>> buildCheckpoint() async {
    final queue = <String>[
      ..._pendingAddresses,
    ];
    final inFlight = _inFlightAddress;
    if (inFlight != null && !queue.contains(inFlight)) {
      queue.insert(0, inFlight);
    }

    return <String, dynamic>{
      'queue': queue,
    };
  }

  @override
  Future<void> restoreFromCheckpoint(Map<String, dynamic> checkpoint) async {
    final restoredQueue = _asStringList(checkpoint['queue']);
    _pendingAddresses
      ..clear()
      ..addAll(restoredQueue);
    _inFlightAddress = null;
  }

  @override
  Future<void> resetWorkState() async {
    _pendingAddresses.clear();
    _inFlightAddress = null;
    _isDraining = false;
  }

  Future<void> _drainQueue() async {
    if (_isDraining || state != BackgroundWorkerState.started) {
      return;
    }

    _isDraining = true;
    try {
      while (state == BackgroundWorkerState.started &&
          _pendingAddresses.isNotEmpty) {
        final address = _pendingAddresses.removeFirst();
        _inFlightAddress = address;
        await checkpoint();

        try {
          await _worker.ensureIndexed(address: address);
        } on Object catch (e, stack) {
          _log.warning('Failed to index address: $address', e, stack);
          _pendingAddresses.addFirst(address);
          await checkpoint();
          rethrow;
        } finally {
          _inFlightAddress = null;
        }

        await checkpoint();
      }
    } finally {
      _isDraining = false;
    }
  }

  List<String> _asStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.map((entry) => entry.toString()).toList(growable: false);
  }
}
