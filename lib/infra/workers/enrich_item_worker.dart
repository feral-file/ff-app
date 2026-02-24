// Reason: worker constructor/entrypoints are intentionally compact.
// ignore_for_file: public_member_api_docs, use_super_parameters
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/workers/background_worker.dart';
import 'package:app/infra/workers/worker_message.dart';
import 'package:app/infra/workers/worker_state_service.dart';
import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:logging/logging.dart';

/// Executes item enrichment batches.
///
/// Pipeline:
/// 1. Receive batch (CID → itemId map) from scheduler
/// 2. Call IndexerService.fetchTokensByCIDs to get metadata
/// 3. Parse AssetToken list from response
/// 4. Write to Drift DB (update playlist_item rows) inside isolate
/// 5. Send workComplete message to scheduler
class EnrichItemWorker extends BackgroundWorker {
  EnrichItemWorker({
    required String workerId,
    required WorkerStateStore workerStateService,
    required String databasePath,
    required String indexerEndpoint,
    required String indexerApiKey,
    SendPort? databaseConnectPort,
    void Function(WorkerMessage)? onMessageSent,
    Logger? logger,
  }) : _databasePath = databasePath,
       _databaseConnectPort = databaseConnectPort,
       _indexerEndpoint = indexerEndpoint,
       _indexerApiKey = indexerApiKey,
       _onMessageSent = onMessageSent,
       super(
         workerId: workerId,
         workerStateService: workerStateService,
         logger: logger,
       );

  final String _databasePath;

  /// [SendPort] for the shared [DriftIsolate].
  ///
  /// Injected by the scheduler via [updateConnectPort] before [start].
  /// Null until set; falls back to direct [NativeDatabase] in tests.
  SendPort? _databaseConnectPort;

  /// Updates the shared DriftIsolate [SendPort].
  // ignore: use_setters_to_change_properties
  void updateConnectPort(SendPort port) => _databaseConnectPort = port;
  final String _indexerEndpoint;
  final String _indexerApiKey;
  final void Function(WorkerMessage)? _onMessageSent;

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
    await spawnIsolate(
      entryPoint: _isolateEntry,
      args: <Object?>[
        _indexerEndpoint,
        _indexerApiKey,
        _databaseConnectPort, // SendPort? — null in tests
        _databasePath, // fallback path used when connectPort is null
      ],
    );

    // Send pending work to isolate
    if (_pendingAssignments.isNotEmpty) {
      _sendWorkToIsolate();
    }
  }

  @override
  Future<void> onPause() async {
    // Save in-flight assignment back to queue for resume
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
    final enrichedCount = message['enrichedCount'];
    final requestedCount = message['requestedCount'];
    final retrievedCount = message['retrievedCount'];
    final matchedCount = message['matchedCount'];
    final failedCount = message['failedCount'];
    final requestedByChain = message['requestedByChain'];
    final retrievedByChain = message['retrievedByChain'];
    final missingByChain = message['missingByChain'];
    final missingCidSamples = message['missingCidSamples'];

    if (type == 'workComplete') {
      final completeMessage = WorkerMessage(
        opcode: WorkerOpcode.workComplete,
        workerId: workerId,
        payload: <String, dynamic>{
          'enrichedCount': enrichedCount ?? 0,
          if (requestedCount != null) 'requestedCount': requestedCount,
          if (retrievedCount != null) 'retrievedCount': retrievedCount,
          if (matchedCount != null) 'matchedCount': matchedCount,
          if (failedCount != null) 'failedCount': failedCount,
          if (requestedByChain != null) 'requestedByChain': requestedByChain,
          if (retrievedByChain != null) 'retrievedByChain': retrievedByChain,
          if (missingByChain != null) 'missingByChain': missingByChain,
          if (missingCidSamples != null) 'missingCidSamples': missingCidSamples,
        },
      );
      _onMessageSent?.call(completeMessage);

      _inFlightAssignment = null;
      _sendWorkToIsolate();
      unawaited(checkpoint());
    } else if (type == 'workFailed') {
      final failedMessage = WorkerMessage(
        opcode: WorkerOpcode.workFailed,
        workerId: workerId,
        payload: <String, dynamic>{
          'error': message['error']?.toString() ?? 'Unknown error',
        },
      );
      _onMessageSent?.call(failedMessage);

      // Re-queue failed assignment
      final inFlight = _inFlightAssignment;
      if (inFlight != null) {
        _pendingAssignments.addFirst(inFlight);
      }
      _inFlightAssignment = null;
      _sendWorkToIsolate();
      unawaited(checkpoint());
    }
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

  // ----------------
  // Isolate entry point
  // ----------------

  static late SendPort _mainSendPort;
  static late Logger _isolateLog;
  static late IndexerService _indexerService;
  static DatabaseService? _dbService;
  static bool _isShuttingDown = false;
  static ReceivePort? _isolateReceivePort;

  static void _isolateEntry(List<Object?> args) {
    final sendPort = args[0]! as SendPort;
    final endpoint = args[1]! as String;
    final apiKey = args[2]! as String;
    final connectPort = args[3] as SendPort?;
    final databasePath = args[4]! as String;

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

    unawaited(_connectAndHandshake(connectPort, databasePath));
  }

  static Future<void> _connectAndHandshake(
    SendPort? connectPort,
    String databasePath,
  ) async {
    _dbService = await _openDatabase(connectPort, databasePath);

    _isolateReceivePort = ReceivePort()..listen(_handleMessageInIsolate);
    _mainSendPort.send(_isolateReceivePort!.sendPort);
  }

  static String _formatApiKeyHeaderValue(String apiKey) {
    if (apiKey.startsWith('ApiKey ')) {
      return apiKey;
    }
    return 'ApiKey $apiKey';
  }

  /// Opens a [DatabaseService] connection inside this isolate.
  ///
  /// Prefers the shared [DriftIsolate] via [connectPort] so all worker
  /// writes are serialised through one executor. Falls back to a direct
  /// [NativeDatabase] when [connectPort] is null (tests).
  static Future<DatabaseService?> _openDatabase(
    SendPort? connectPort,
    String path,
  ) async {
    if (connectPort != null) {
      try {
        final connection = await DriftIsolate.fromConnectPort(
          connectPort,
        ).connect();
        _isolateLog.info('Connected to shared DriftIsolate');
        return DatabaseService(AppDatabase.fromConnection(connection));
      } on Object catch (e, stack) {
        _isolateLog.warning('DriftIsolate connect failed', e, stack);
        return null;
      }
    }
    if (path.isEmpty) {
      return null;
    }
    try {
      final db = AppDatabase.forTesting(
        NativeDatabase(
          File(path),
          setup: (rawDb) {
            rawDb
              ..execute('PRAGMA busy_timeout = 5000')
              ..execute('PRAGMA journal_mode = WAL');
          },
        ),
      );
      _isolateLog.info('Opened direct NativeDatabase at $path');
      return DatabaseService(db);
    } on Object catch (e, stack) {
      _isolateLog.warning('Failed to open NativeDatabase at $path', e, stack);
      return null;
    }
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

  static Future<void> _enrichBatch(Map<String, String> cidToItemId) async {
    try {
      if (_isShuttingDown) {
        return;
      }

      final requestedCount = cidToItemId.length;
      _isolateLog.info('Enriching batch: requested=$requestedCount');

      // Fetch tokens by CIDs from the indexer API
      final cids = cidToItemId.keys.toList();
      final tokens = await _indexerService.fetchTokensByCIDs(tokenCids: cids);
      final retrievedCount = tokens.length;
      final requestedByChain = _countByChainPrefix(cids);
      final retrievedByChain = _countByChainPrefix(
        tokens.map((t) => t.cid).toList(growable: false),
      );

      // Match returned tokens to their item IDs and write to DB
      final enrichments = tokens
          .where((t) => cidToItemId.containsKey(t.cid))
          .map((t) => (cidToItemId[t.cid]!, t))
          .toList(growable: false);
      final matchedCount = enrichments.length;
      final returnedCidSet = tokens.map((t) => t.cid).toSet();
      final missingCids = cids.where((cid) => !returnedCidSet.contains(cid));
      final missingByChain = _countByChainPrefix(missingCids.toList());
      final missingCidSamples = missingCids.take(3).toList(growable: false);
      final failedItemIds = cids
          .where((cid) => !returnedCidSet.contains(cid))
          .map((cid) => cidToItemId[cid])
          .whereType<String>()
          .toList(growable: false);
      final failedCount = failedItemIds.length;

      final service = _dbService;
      if (service != null && enrichments.isNotEmpty) {
        await service.enrichPlaylistItemsWithTokensBatch(
          enrichments: enrichments,
        );
        if (failedItemIds.isNotEmpty) {
          await service.markPlaylistItemsEnrichmentFailed(failedItemIds);
        }
        _isolateLog.info(
          'Enrichment result: requested=$requestedCount, '
          'retrieved=$retrievedCount, matched=$matchedCount, '
          'failed=$failedCount, '
          'requestedByChain=$requestedByChain, '
          'retrievedByChain=$retrievedByChain, '
          'missingByChain=$missingByChain, '
          'missingCidSamples=$missingCidSamples',
        );
      } else if (enrichments.isEmpty) {
        if (service != null && failedItemIds.isNotEmpty) {
          await service.markPlaylistItemsEnrichmentFailed(failedItemIds);
        }
        _isolateLog.fine(
          'Enrichment result: requested=$requestedCount, '
          'retrieved=$retrievedCount, matched=0, '
          'failed=$failedCount, '
          'requestedByChain=$requestedByChain, '
          'retrievedByChain=$retrievedByChain, '
          'missingByChain=$missingByChain, '
          'missingCidSamples=$missingCidSamples',
        );
      } else {
        _isolateLog.warning('No DB service — skipping enrichment writes');
      }

      if (!_isShuttingDown) {
        _mainSendPort.send(<String, Object>{
          'type': 'workComplete',
          'enrichedCount': enrichments.length,
          'requestedCount': requestedCount,
          'retrievedCount': retrievedCount,
          'matchedCount': matchedCount,
          'failedCount': failedCount,
          'requestedByChain': requestedByChain,
          'retrievedByChain': retrievedByChain,
          'missingByChain': missingByChain,
          'missingCidSamples': missingCidSamples,
        });
      }
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

    await _closeDatabase();
    _isolateReceivePort?.close();
    _isolateReceivePort = null;

    _mainSendPort.send(<String, Object>{
      'type': 'lifecycleAck',
      'action': action,
    });
  }

  static Future<void> _closeDatabase() async {
    final service = _dbService;
    _dbService = null;
    if (service == null) {
      return;
    }
    try {
      await service.checkpoint();
      await service.close();
    } on Object catch (e, stack) {
      _isolateLog.warning('Failed closing enrich worker database', e, stack);
    }
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
