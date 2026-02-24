// Reason: worker constructor/entrypoints are intentionally compact.
// ignore_for_file: public_member_api_docs, use_super_parameters
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';

import 'package:app/domain/models/indexer/asset_token.dart';
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

/// Self-contained worker for indexing blockchain addresses.
///
/// Pipeline:
/// 1. Receive address from scheduler
/// 2. Trigger indexing via IndexerService
/// 3. Poll indexing workflow status until complete
/// 4. Fetch tokens for address
/// 5. Write tokens to Drift DB inside isolate
/// 6. Send workComplete message to scheduler
class IndexAddressWorker extends BackgroundWorker {
  IndexAddressWorker({
    required String workerId,
    required WorkerStateStore workerStateService,
    required IndexerService Function() indexerServiceFactory,
    required String databasePath,
    required String indexerEndpoint,
    required String indexerApiKey,
    SendPort? databaseConnectPort,
    Logger? logger,
  }) : _indexerServiceFactory = indexerServiceFactory,
       _databasePath = databasePath,
       _databaseConnectPort = databaseConnectPort,
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
  final String _databasePath;

  /// Updates the shared DriftIsolate [SendPort].
  ///
  /// Must be called by the scheduler before [start] when the shared Drift
  /// isolate is available. Safe to call multiple times; subsequent calls
  /// only affect future [start] invocations.
  // ignore: use_setters_to_change_properties
  void updateConnectPort(SendPort port) => _databaseConnectPort = port;

  /// [SendPort] for the shared [DriftIsolate].
  ///
  /// Set to null at construction; injected by the scheduler via
  /// [updateConnectPort] before [start] is called. When null the isolate
  /// falls back to a direct [NativeDatabase] connection (used in tests).
  SendPort? _databaseConnectPort;
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

    // Deduplicate
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
    await spawnIsolate(
      entryPoint: _isolateEntry,
      args: <Object?>[
        _indexerEndpoint,
        _indexerApiKey,
        _databaseConnectPort, // SendPort? — null in tests
        _databasePath, // fallback path used when connectPort is null
      ],
    );

    // Send any pending work to isolate
    if (_pendingAddresses.isNotEmpty) {
      _sendWorkToIsolate();
    }
  }

  @override
  Future<void> onPause() async {
    // Save in-flight address back to queue for resume
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

    if (type == 'workComplete') {
      Logger(
        'IndexAddressWorker',
      ).info('Index worker completed address=$address');
      _inFlightAddress = null;
      _sendWorkToIsolate(); // Send next work item if available
      unawaited(checkpoint());
    } else if (type == 'workFailed') {
      final error = message['error']?.toString() ?? 'Unknown error';
      Logger(
        'IndexAddressWorker',
      ).warning('Index worker failed address=$address error=$error');
      // Re-queue failed address
      if (address.isNotEmpty && !_pendingAddresses.contains(address)) {
        _pendingAddresses.addFirst(address);
      }
      _inFlightAddress = null;
      _sendWorkToIsolate();
      unawaited(checkpoint());
    }
  }

  List<String> _asStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }
    return value.map((entry) => entry.toString()).toList(growable: false);
  }

  // ----------------
  // Isolate entry point and worker logic
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

    // Connect to DB asynchronously, then send the handshake.
    unawaited(_connectAndHandshake(connectPort, databasePath));
  }

  /// Connects to the database (via [DriftIsolate] if [connectPort] is
  /// provided, otherwise directly via [NativeDatabase]), then sends the
  /// isolate handshake [SendPort] to the main isolate.
  static Future<void> _connectAndHandshake(
    SendPort? connectPort,
    String databasePath,
  ) async {
    _dbService = await _openDatabase(connectPort, databasePath);

    _isolateReceivePort = ReceivePort()..listen(_handleMessageInIsolate);
    _mainSendPort.send(_isolateReceivePort!.sendPort);
  }

  /// Opens a [DatabaseService] connection inside this isolate.
  ///
  /// When [connectPort] is provided, connects to the shared [DriftIsolate]
  /// spawned by the scheduler so all worker writes are serialised through
  /// a single Drift executor (no concurrent SQLite write-lock contention).
  ///
  /// Falls back to a direct [NativeDatabase] connection (used in tests where
  /// no [DriftIsolate] is available).
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
    // Fallback: direct file connection (tests pass databasePath: ':memory:').
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

      // Step 1: Fast-path by reading already-indexed tokens first.
      final existingTokens = await _indexerService.fetchTokensByAddresses(
        addresses: <String>[address],
        limit: 250,
        offset: 0,
      );
      if (existingTokens.isNotEmpty) {
        await _writeTokensToDB(address, existingTokens);
        if (!_isShuttingDown) {
          _mainSendPort.send(<String, Object>{
            'type': 'workComplete',
            'address': address,
            'tokenCount': existingTokens.length,
          });
        }
        _isolateLog.info(
          'Completed indexing address via fast-path: $address '
          '(tokens=${existingTokens.length})',
        );
        return;
      }

      // Step 2: Trigger indexing when no tokens are available yet.
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

      // Step 3: Poll workflow status
      const maxAttempts = 60; // 5 minutes with 5-second intervals
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

      // Step 4: Fetch tokens
      final tokens = await _indexerService.fetchTokensByAddresses(
        addresses: <String>[address],
        limit: 250,
        offset: 0,
      );

      // Step 5: Write to database
      await _writeTokensToDB(address, tokens);

      // Step 6: Send completion message
      if (!_isShuttingDown) {
        _mainSendPort.send(<String, Object>{
          'type': 'workComplete',
          'address': address,
          'tokenCount': tokens.length,
        });
      }

      _isolateLog.info('Completed indexing address: $address');
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

  static Future<void> _writeTokensToDB(
    String address,
    List<AssetToken> tokens,
  ) async {
    final service = _dbService;
    if (service == null) {
      _isolateLog.warning('No DB service — skipping token write for $address');
      return;
    }
    await service.ingestTokensForAddress(address: address, tokens: tokens);
    _isolateLog.info('Wrote ${tokens.length} tokens for $address to DB');
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
      _isolateLog.warning('Failed closing index worker database', e, stack);
    }
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
