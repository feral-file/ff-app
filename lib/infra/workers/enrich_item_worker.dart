// Reason: worker constructor/entrypoints are intentionally compact.
// ignore_for_file: public_member_api_docs, use_super_parameters
import 'dart:async';
import 'dart:collection';
import 'dart:isolate';

import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_message.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:logging/logging.dart';

/// Executes item enrichment batches.
///
/// Pipeline:
/// 1. Receive batch (CID → itemId map) from scheduler
/// 2. Call IndexerService.getManualTokens to fetch metadata (in isolate)
/// 3. Send serialised token payload back to the main isolate as 'writeResult'
/// 4. Main isolate writes to DB via the injected [DatabaseService]
/// 5. Main isolate emits workComplete to scheduler
///
/// Keeping the DB write on the main isolate eliminates the DB connection from
/// the worker isolate entirely. This removes the async DriftIsolate handshake
/// from the isolate startup path, making the worker handshake synchronous and
/// preventing OS thread-slot contention during app startup.
class EnrichItemWorker extends BackgroundWorker {
  EnrichItemWorker({
    required String workerId,
    required WorkerStateStore workerStateService,
    required DatabaseService databaseService,
    required String indexerEndpoint,
    required String indexerApiKey,
    void Function(WorkerMessage)? onMessageSent,
    Logger? logger,
  }) : _databaseService = databaseService,
       _indexerEndpoint = indexerEndpoint,
       _indexerApiKey = indexerApiKey,
       _onMessageSent = onMessageSent,
       super(
         workerId: workerId,
         workerStateService: workerStateService,
         logger: logger,
       );

  /// Database service on the main isolate used to persist enrichment results.
  final DatabaseService _databaseService;
  final String _indexerEndpoint;
  final String _indexerApiKey;
  final void Function(WorkerMessage)? _onMessageSent;
  final Logger _log = Logger('EnrichItemWorker');

  final Queue<Map<String, String>> _pendingAssignments = Queue();
  Map<String, String>? _inFlightAssignment;

  @override
  bool get hasRemainingWork =>
      _pendingAssignments.isNotEmpty || _inFlightAssignment != null;

  /// Enqueue an enrichment batch assignment.
  Future<void> enqueueAssignment(Map<String, String> cidToItemId) async {
    if (state == BackgroundWorkerState.stopped) {
      return;
    }

    if (cidToItemId.isEmpty) {
      return;
    }

    _pendingAssignments.add(cidToItemId);
    await checkpoint();

    if (state == BackgroundWorkerState.started && isIsolateRunning) {
      _sendWorkToIsolate();
    }
  }

  void _sendWorkToIsolate() {
    if (_pendingAssignments.isEmpty || _inFlightAssignment != null) {
      return;
    }

    final assignment = _pendingAssignments.removeFirst();
    _inFlightAssignment = assignment;

    sendMessage(
      WorkerMessage(
        opcode: WorkerOpcode.enqueueWork,
        workerId: workerId,
        payload: <String, dynamic>{'batch': assignment},
      ),
    );
  }

  @override
  Future<void> onStart() async {
    // The isolate no longer connects to a DB at entry — handshake is
    // synchronous, completing in microseconds rather than waiting for a
    // DriftIsolate round-trip.
    await spawnIsolate(
      entryPoint: _isolateEntry,
      args: <Object?>[
        _indexerEndpoint,
        _indexerApiKey,
      ],
    );

    if (_pendingAssignments.isNotEmpty) {
      _sendWorkToIsolate();
    }
  }

  @override
  Future<void> onPause() async {
    // Save in-flight assignment back to queue for resume.
    // The write may still be in progress on the main isolate; after it
    // completes, _processWriteResult guards against state != started.
    final inFlight = _inFlightAssignment;
    if (inFlight != null) {
      _pendingAssignments.addFirst(inFlight);
      _inFlightAssignment = null;
    }

    await shutdownIsolateGracefully(opcode: WorkerOpcode.pause);
  }

  @override
  Future<void> onStop() async {
    await shutdownIsolateGracefully(opcode: WorkerOpcode.stop);
  }

  @override
  Future<Map<String, dynamic>> buildCheckpoint() async {
    final assignments = <Map<String, String>>[..._pendingAssignments];
    final inFlight = _inFlightAssignment;
    if (inFlight != null) {
      assignments.insert(0, inFlight);
    }

    return <String, dynamic>{
      'assignments': assignments,
    };
  }

  @override
  Future<void> restoreFromCheckpoint(Map<String, dynamic> checkpoint) async {
    final restoredAssignments = _asAssignmentList(checkpoint['assignments']);
    _pendingAssignments
      ..clear()
      ..addAll(restoredAssignments);
    _inFlightAssignment = null;
  }

  @override
  Future<void> resetWorkState() async {
    _pendingAssignments.clear();
    _inFlightAssignment = null;
  }

  @override
  void onIsolateMessage(dynamic message) {
    if (message is! Map) {
      return;
    }

    final type = message['type']?.toString() ?? '';

    if (type == 'writeResult') {
      // Isolate has finished the HTTP fetch; write results to DB on the main
      // isolate, then emit workComplete (or workFailed on DB error).
      unawaited(
        _processWriteResult(Map<dynamic, dynamic>.from(message)),
      );
      return;
    }

    if (type == 'workFailed') {
      final failedMessage = WorkerMessage(
        opcode: WorkerOpcode.workFailed,
        workerId: workerId,
        payload: <String, dynamic>{
          'error': message['error']?.toString() ?? 'Unknown error',
        },
      );
      _onMessageSent?.call(failedMessage);

      final inFlight = _inFlightAssignment;
      if (inFlight != null) {
        _pendingAssignments.addFirst(inFlight);
      }
      _inFlightAssignment = null;
      _sendWorkToIsolate();
      unawaited(checkpoint());
    }
  }

  /// Forwards enrichment results from the isolate to the background write queue.
  ///
  /// No deserialization happens on the main isolate. Raw JSON payloads are
  /// forwarded to DatabaseService.enrichBatchFromRaw, which routes them to
  /// the always-on write-queue isolate where all CPU and SQL work occurs.
  Future<void> _processWriteResult(Map<dynamic, dynamic> message) async {
    if (state != BackgroundWorkerState.started) return;

    final enrichedCount = message['enrichedCount'] as int? ?? 0;
    final requestedCount = message['requestedCount'];
    final retrievedCount = message['retrievedCount'];
    final matchedCount = message['matchedCount'];
    final failedCount = message['failedCount'];
    final requestedByChain = message['requestedByChain'];
    final retrievedByChain = message['retrievedByChain'];
    final missingByChain = message['missingByChain'];
    final missingCidSamples = message['missingCidSamples'];

    final rawEnrichments =
        (message['enrichments'] as List? ?? const []).cast<Object?>();
    final failedItemIds =
        (message['failedItemIds'] as List? ?? const [])
            .map((e) => e.toString())
            .toList(growable: false);

    try {
      await _databaseService.enrichBatchFromRaw(
        rawEnrichments: rawEnrichments,
        failedItemIds: failedItemIds,
      );
    } on Object catch (e, stack) {
      _log.warning('DB write failed for enrichment batch', e, stack);
      // Re-check state after await; pause may have fired while we were writing.
      if (state != BackgroundWorkerState.started) return;
      _onMessageSent?.call(
        WorkerMessage(
          opcode: WorkerOpcode.workFailed,
          workerId: workerId,
          payload: <String, dynamic>{'error': e.toString()},
        ),
      );
      final inFlight = _inFlightAssignment;
      if (inFlight != null) {
        _pendingAssignments.addFirst(inFlight);
      }
      _inFlightAssignment = null;
      _sendWorkToIsolate();
      unawaited(checkpoint());
      return;
    }

    // Re-check: a pause/stop may have fired while the DB write was in progress.
    if (state != BackgroundWorkerState.started) return;

    _onMessageSent?.call(
      WorkerMessage(
        opcode: WorkerOpcode.workComplete,
        workerId: workerId,
        payload: <String, dynamic>{
          'enrichedCount': enrichedCount,
          'requestedCount': ?requestedCount,
          'retrievedCount': ?retrievedCount,
          'matchedCount': ?matchedCount,
          'failedCount': ?failedCount,
          'requestedByChain': ?requestedByChain,
          'retrievedByChain': ?retrievedByChain,
          'missingByChain': ?missingByChain,
          'missingCidSamples': ?missingCidSamples,
        },
      ),
    );
    _inFlightAssignment = null;
    _sendWorkToIsolate();
    unawaited(checkpoint());
  }

  List<Map<String, String>> _asAssignmentList(Object? value) {
    if (value is! List) {
      return const <Map<String, String>>[];
    }
    return value
        .whereType<Map<Object?, Object?>>()
        .map(Map<String, String>.from)
        .toList(growable: false);
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

    _isolateLog = Logger('EnrichItemWorker[Isolate]');
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

  static String _formatApiKeyHeaderValue(String apiKey) {
    if (apiKey.startsWith('ApiKey ')) {
      return apiKey;
    }
    return 'ApiKey $apiKey';
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
        final batch = workerMessage.payload['batch'] as Map?;
        if (batch != null) {
          final cidToItemId = Map<String, String>.from(batch);
          unawaited(_enrichBatch(cidToItemId));
        }
      }
    } on Object catch (e, stack) {
      _isolateLog.warning('Failed to handle message in isolate', e, stack);
    }
  }

  /// Fetches token metadata for the given CID→itemId batch and sends the
  /// results back to the main isolate as 'writeResult'.
  ///
  /// The main isolate is responsible for persisting the data via its own
  /// DatabaseService, keeping this isolate free of any DB connection.
  static Future<void> _enrichBatch(Map<String, String> cidToItemId) async {
    try {
      if (_isShuttingDown) {
        return;
      }

      final requestedCount = cidToItemId.length;
      _isolateLog.info('Enriching batch: requested=$requestedCount');

      final cids = cidToItemId.keys.toList(growable: false);
      final tokens = await _indexerService.getManualTokens(tokenCids: cids);
      final retrievedCount = tokens.length;
      final requestedByChain = _countByChainPrefix(cids);
      final retrievedByChain = _countByChainPrefix(
        tokens.map((t) => t.cid).toList(growable: false),
      );

      final enrichments =
          tokens
              .where((t) => cidToItemId.containsKey(t.cid))
              .map((t) => (cidToItemId[t.cid]!, t))
              .toList(growable: false);
      final matchedCount = enrichments.length;
      final returnedCidSet = tokens.map((t) => t.cid).toSet();
      final missingCids =
          cids.where((cid) => !returnedCidSet.contains(cid)).toList();
      final missingByChain = _countByChainPrefix(missingCids);
      final missingCidSamples = missingCids.take(3).toList(growable: false);
      final failedItemIds =
          missingCids
              .map((cid) => cidToItemId[cid])
              .whereType<String>()
              .toList(growable: false);
      final failedCount = failedItemIds.length;

      _isolateLog.fine(
        'Enrichment fetched: requested=$requestedCount, '
        'retrieved=$retrievedCount, matched=$matchedCount, '
        'failed=$failedCount',
      );

      if (_isShuttingDown) {
        return;
      }

      // Send serialised results to main isolate for DB persistence.
      _mainSendPort.send(<String, Object?>{
        'type': 'writeResult',
        'enrichments': enrichments
            .map(
              (e) => <String, Object?>{
                'itemId': e.$1,
                'tokenJson': e.$2.toRestJson(),
              },
            )
            .toList(growable: false),
        'failedItemIds': failedItemIds,
        'enrichedCount': matchedCount,
        'requestedCount': requestedCount,
        'retrievedCount': retrievedCount,
        'matchedCount': matchedCount,
        'failedCount': failedCount,
        'requestedByChain': requestedByChain,
        'retrievedByChain': retrievedByChain,
        'missingByChain': missingByChain,
        'missingCidSamples': missingCidSamples,
      });
    } on Object catch (e, stack) {
      _isolateLog.warning('Failed to enrich batch', e, stack);
      if (!_isShuttingDown) {
        _mainSendPort.send(<String, Object>{
          'type': 'workFailed',
          'error': e.toString(),
        });
      }
    }
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
}

Map<String, int> _countByChainPrefix(List<String> cids) {
  final counts = <String, int>{};
  for (final cid in cids) {
    final parts = cid.split(':');
    if (parts.length < 4) continue;
    final chain = '${parts[0]}:${parts[1]}';
    counts.update(chain, (v) => v + 1, ifAbsent: () => 1);
  }
  return counts;
}
