// Reason: worker constructor/entrypoints are intentionally compact.
// ignore_for_file: public_member_api_docs, use_super_parameters
import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_message.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:logging/logging.dart';

/// Self-contained worker for indexing blockchain addresses.
///
/// Pipeline:
/// 1. Receive address from scheduler
/// 2. Trigger indexing via IndexerService (in isolate)
/// 3. Poll indexing workflow status until complete (in isolate)
/// 4. Fetch tokens for address (in isolate)
/// 5. Send serialised token payload to main isolate as 'writeResult'
/// 6. Main isolate forwards raw JSON to DatabaseService.ingestTokensForAddressFromRaw
/// 7. DatabaseWriteQueue isolate: deserialise → transform → SQL write
/// 8. Main isolate emits workComplete to scheduler
///
/// No deserialization or DB work happens on the main isolate; it only
/// forwards the payload to the always-on write-queue isolate.
class IndexAddressWorker extends BackgroundWorker {
  IndexAddressWorker({
    required String workerId,
    required WorkerStateStore workerStateService,
    required IndexerService Function() indexerServiceFactory,
    required DatabaseService databaseService,
    required String indexerEndpoint,
    required String indexerApiKey,
    Logger? logger,
  }) : _indexerServiceFactory = indexerServiceFactory,
       _databaseService = databaseService,
       _indexerEndpoint = indexerEndpoint,
       _indexerApiKey = indexerApiKey,
       super(
         workerId: workerId,
         workerStateService: workerStateService,
         logger: logger,
       );

  // Used in tests for dependency injection; the isolate creates its own
  // IndexerService from endpoint/apiKey args at spawn time.
  // ignore: unused_field
  final IndexerService Function() _indexerServiceFactory;

  /// Database service on the main isolate used to persist token results.
  final DatabaseService _databaseService;
  final String _indexerEndpoint;
  final String _indexerApiKey;

  final Queue<String> _pendingAddresses = Queue<String>();
  String? _inFlightAddress;

  @override
  bool get hasRemainingWork =>
      _pendingAddresses.isNotEmpty || _inFlightAddress != null;

  /// Enqueue an address for indexing.
  Future<void> enqueueAddress(String address) async {
    if (state == BackgroundWorkerState.stopped) {
      return;
    }

    final normalized = _normalizeAddress(address);
    if (normalized.isEmpty) {
      return;
    }

    if (_pendingAddresses.contains(normalized) ||
        _inFlightAddress == normalized) {
      return;
    }

    _pendingAddresses.add(normalized);
    await checkpoint();

    if (state == BackgroundWorkerState.started && isIsolateRunning) {
      _sendWorkToIsolate();
    }
  }

  String _normalizeAddress(String address) {
    final trimmed = address.trim();
    if (_isEthereumAddress(trimmed)) {
      if (trimmed.startsWith('0X')) {
        return '0x${trimmed.substring(2)}'.toLowerCase();
      }
      return trimmed.toLowerCase();
    }
    return trimmed;
  }

  bool _isEthereumAddress(String address) {
    return address.startsWith('0x') || address.startsWith('0X');
  }

  void _sendWorkToIsolate() {
    if (_pendingAddresses.isEmpty || _inFlightAddress != null) {
      return;
    }

    final address = _pendingAddresses.removeFirst();
    _inFlightAddress = address;

    sendMessage(
      WorkerMessage(
        opcode: WorkerOpcode.enqueueWork,
        workerId: workerId,
        payload: <String, dynamic>{'address': address},
      ),
    );
  }

  @override
  Future<void> onStart() async {
    // The isolate no longer connects to a DB at entry — handshake is
    // synchronous, completing without waiting for a DriftIsolate round-trip.
    await spawnIsolate(
      entryPoint: _isolateEntry,
      args: <Object?>[
        _indexerEndpoint,
        _indexerApiKey,
      ],
    );

    if (_pendingAddresses.isNotEmpty) {
      _sendWorkToIsolate();
    }
  }

  @override
  Future<void> onPause() async {
    // Save in-flight address back to queue for resume.
    final inFlight = _inFlightAddress;
    if (inFlight != null && !_pendingAddresses.contains(inFlight)) {
      _pendingAddresses.addFirst(inFlight);
      _inFlightAddress = null;
    }

    await shutdownIsolateGracefully(opcode: WorkerOpcode.pause);
  }

  @override
  Future<void> onStop() async {
    await shutdownIsolateGracefully(opcode: WorkerOpcode.stop);
  }

  @override
  Future<Map<String, dynamic>> buildCheckpoint() async {
    final queue = <String>[..._pendingAddresses];
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
  }

  @override
  void onIsolateMessage(dynamic message) {
    if (message is! Map) {
      return;
    }

    final type = message['type']?.toString() ?? '';
    final address = message['address']?.toString() ?? '';

    if (type == 'writeResult') {
      // Isolate fetched tokens successfully; write to DB on the main isolate.
      unawaited(
        _processWriteResult(Map<dynamic, dynamic>.from(message)),
      );
      return;
    }

    if (type == 'workFailed') {
      final error = message['error']?.toString() ?? 'Unknown error';
      Logger('IndexAddressWorker').warning(
        'Index worker failed address=$address error=$error',
      );
      if (address.isNotEmpty && !_pendingAddresses.contains(address)) {
        _pendingAddresses.addFirst(address);
      }
      _inFlightAddress = null;
      _sendWorkToIsolate();
      unawaited(checkpoint());
    }
  }

  /// Forwards the raw token payload from the worker isolate to the background
  /// write queue via DatabaseService.ingestTokensForAddressFromRaw.
  ///
  /// No deserialization or transformation happens on the main isolate.
  /// All CPU-heavy work (JSON parsing, domain transformation, companion
  /// building, SQL writes) runs in the always-on write-queue isolate.
  Future<void> _processWriteResult(Map<dynamic, dynamic> message) async {
    if (state != BackgroundWorkerState.started) return;

    final address = message['address']?.toString() ?? '';
    final rawTokens = (message['tokens'] as List? ?? const []).cast<Object?>();
    final tokenCount = message['tokenCount'] as int? ?? 0;

    try {
      await _databaseService.ingestTokensForAddressFromRaw(
        address: address,
        rawTokensJson: rawTokens,
      );
    } on Object catch (e, stack) {
      Logger('IndexAddressWorker').warning(
        'DB write failed for address=$address',
        e,
        stack,
      );
      if (state != BackgroundWorkerState.started) return;
      if (address.isNotEmpty && !_pendingAddresses.contains(address)) {
        _pendingAddresses.addFirst(address);
      }
      _inFlightAddress = null;
      _sendWorkToIsolate();
      unawaited(checkpoint());
      return;
    }

    if (state != BackgroundWorkerState.started) return;

    Logger('IndexAddressWorker').info(
      'Completed indexing address=$address tokens=$tokenCount',
    );
    _inFlightAddress = null;
    _sendWorkToIsolate();
    unawaited(checkpoint());
  }

  List<String> _asStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.map((entry) => entry.toString()).toList(growable: false);
  }

  // ─────────────────────────────────────────────
  // Isolate entry point — no DB connection here.
  // ─────────────────────────────────────────────

  static late SendPort _mainSendPort;
  static late Logger _isolateLog;
  static late IndexerService _indexerService;
  static bool _isShuttingDown = false;
  static ReceivePort? _isolateReceivePort;

  static void _isolateEntry(List<Object?> args) {
    final sendPort = args[0]! as SendPort;
    final endpoint = args[1]! as String;
    final apiKey = args[2]! as String;

    _isolateLog = Logger('IndexAddressWorker[Isolate]');
    _mainSendPort = sendPort;
    _isShuttingDown = false;

    _indexerService = IndexerService(
      client: IndexerClient(
        endpoint: endpoint,
        defaultHeaders: <String, String>{
          'Content-Type': 'application/json',
          if (apiKey.isNotEmpty)
            'Authorization': _formatApiKeyHeaderValue(apiKey),
        },
      ),
    );

    // Handshake is now synchronous — no DB connection to await.
    _isolateReceivePort = ReceivePort()..listen(_handleMessageInIsolate);
    _mainSendPort.send(_isolateReceivePort!.sendPort);
  }

  static void _handleMessageInIsolate(dynamic message) {
    if (message is! List || message.length < 3) {
      return;
    }

    try {
      final workerMessage = WorkerMessage.fromList(message);

      if (workerMessage.opcode == WorkerOpcode.pause ||
          workerMessage.opcode == WorkerOpcode.stop) {
        unawaited(_shutdownIsolate(workerMessage.opcode.name));
        return;
      }
      if (_isShuttingDown) {
        return;
      }

      if (workerMessage.opcode == WorkerOpcode.enqueueWork) {
        final address = workerMessage.payload['address'] as String?;
        if (address != null && address.isNotEmpty) {
          unawaited(_processAddress(address));
        }
      } else {
        _isolateLog.warning('Unknown opcode: ${workerMessage.opcode}');
      }
    } on Object catch (e, stack) {
      _isolateLog.warning('Failed to handle message in isolate', e, stack);
    }
  }

  static Future<void> _processAddress(String address) async {
    try {
      if (_isShuttingDown) {
        return;
      }

      _isolateLog.info('Processing address: $address');

      // Fast-path: read already-indexed tokens first to avoid a polling round.
      final existingTokens = await _indexerService.fetchTokensByAddresses(
        addresses: <String>[address],
        limit: 250,
        offset: 0,
      );
      if (existingTokens.isNotEmpty) {
        _sendWriteResult(address, existingTokens);
        _isolateLog.info(
          'Fast-path completed address=$address '
          'tokens=${existingTokens.length}',
        );
        return;
      }

      // Trigger indexing when no tokens are available yet.
      final results = await _indexerService.indexAddressesList(<String>[
        address,
      ]);

      var workflowId = '';
      for (final result in results) {
        if (_addressesEqual(result.address, address)) {
          workflowId = result.workflowId;
          break;
        }
      }

      if (workflowId.isEmpty) {
        throw Exception('No workflow ID returned for address: $address');
      }

      const maxAttempts = 60;
      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        if (_isShuttingDown) {
          return;
        }
        final status = await _indexerService.getAddressIndexingJobStatus(
          workflowId: workflowId,
        );

        if (status.status.isDone) {
          if (!status.status.isSuccess) {
            throw Exception(
              'Indexing failed with status: ${status.status.name}',
            );
          }
          break;
        }

        await Future<void>.delayed(const Duration(seconds: 5));
      }

      if (_isShuttingDown) {
        return;
      }

      final tokens = await _indexerService.fetchTokensByAddresses(
        addresses: <String>[address],
        limit: 250,
        offset: 0,
      );

      _sendWriteResult(address, tokens);
      _isolateLog.info('Completed indexing address=$address');
    } on Object catch (e, stack) {
      _isolateLog.warning('Failed to process address: $address', e, stack);
      if (!_isShuttingDown) {
        _mainSendPort.send(<String, Object>{
          'type': 'workFailed',
          'address': address,
          'error': e.toString(),
        });
      }
    }
  }

  /// Sends fetched tokens to the main isolate for DB persistence.
  static void _sendWriteResult(String address, List<AssetToken> tokens) {
    if (_isShuttingDown) return;
    _mainSendPort.send(<String, Object?>{
      'type': 'writeResult',
      'address': address,
      'tokens': tokens.map((t) => t.toRestJson()).toList(growable: false),
      'tokenCount': tokens.length,
    });
  }

  static Future<void> _shutdownIsolate(String action) async {
    if (_isShuttingDown) {
      return;
    }
    _isShuttingDown = true;

    // No DB to close — shutdown is now synchronous.
    _isolateReceivePort?.close();
    _isolateReceivePort = null;

    _mainSendPort.send(<String, Object>{
      'type': 'lifecycleAck',
      'action': action,
    });
  }

  static bool _addressesEqual(String left, String right) {
    final leftIsEth = left.startsWith('0x') || left.startsWith('0X');
    final rightIsEth = right.startsWith('0x') || right.startsWith('0X');
    if (leftIsEth || rightIsEth) {
      return left.toLowerCase() == right.toLowerCase();
    }
    return left == right;
  }

  static String _formatApiKeyHeaderValue(String apiKey) {
    if (apiKey.startsWith('ApiKey ')) {
      return apiKey;
    }
    return 'ApiKey $apiKey';
  }
}
