// ignore_for_file: public_member_api_docs // Reason: isolate wire protocol; keep stable.

import 'dart:async';
import 'dart:isolate';

import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/rebuild_metadata_result.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:logging/logging.dart';

/// Interface for indexer isolate operations. Allows injection of fakes in tests.
abstract class IndexerServiceIsolateOperations {
  Future<List<AddressIndexingResult>> indexAddressesList(List<String> addresses);
  Future<AddressIndexingJobResponse> getAddressIndexingJobStatus(
    String workflowId,
  );
  Future<TokensPage> fetchTokensPageByAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  });
  Future<AssetToken?> rebuildMetadataAndFetchToken(String cid);
}

/// Runs indexer API calls in a dedicated isolate to avoid blocking the main isolate.
///
/// Spawns a long-lived isolate with [IndexerService]. All network calls run
/// in the isolate; results are serialized and sent back to the main isolate.
class IndexerServiceIsolate implements IndexerServiceIsolateOperations {
  /// Creates an [IndexerServiceIsolate].
  IndexerServiceIsolate({
    required this.endpoint,
    required this.apiKey,
    Logger? logger,
  }) : _log = logger ?? Logger('IndexerServiceIsolate');

  final String endpoint;
  final String apiKey;
  final Logger _log;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _sendPort;
  final _ready = Completer<void>();
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  int _requestId = 0;

  /// Whether the isolate is running.
  bool get isRunning => _isolate != null;

  /// Resolves when the isolate handshake is complete.
  Future<void> get ready => _ready.future;

  /// Starts the isolate. Must be called before any other method.
  Future<void> start() async {
    if (_isolate != null) return;

    _receivePort = ReceivePort();
    _receivePort!.listen(_onMessage);

    _isolate = await Isolate.spawn<List<Object?>>(
      _isolateEntry,
      <Object?>[
        _receivePort!.sendPort,
        endpoint,
        apiKey,
      ],
      errorsAreFatal: false,
    );

    await _ready.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException(
          'IndexerServiceIsolate handshake timed out',
          const Duration(seconds: 30),
        );
      },
    );

    _log.info('IndexerServiceIsolate started');
  }

  /// Stops the isolate.
  Future<void> stop() async {
    if (_isolate == null) return;

    _receivePort?.close();
    _receivePort = null;
    _sendPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;

    for (final c in _pending.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('IndexerServiceIsolate stopped'));
      }
    }
    _pending.clear();

    _log.info('IndexerServiceIsolate stopped');
  }

  Future<void> _ensureStarted() async {
    if (_isolate != null) return;
    await start();
  }

  @override
  Future<List<AddressIndexingResult>> indexAddressesList(
    List<String> addresses,
  ) async {
    await _ensureStarted();
    final result = await _sendRequest('indexAddressesList', {
      'addresses': addresses,
    });

    final jobs = result['jobs'] as List<Object?>? ?? const [];
    return jobs
        .whereType<Map<Object?, Object?>>()
        .map(
          (e) => AddressIndexingResult.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  @override
  Future<AddressIndexingJobResponse> getAddressIndexingJobStatus(
    String workflowId,
  ) async {
    await _ensureStarted();
    final result = await _sendRequest('getAddressIndexingJobStatus', {
      'workflowId': workflowId,
    });

    return AddressIndexingJobResponse.fromJson(
      Map<String, dynamic>.from(result),
    );
  }

  @override
  Future<TokensPage> fetchTokensPageByAddresses({
    required List<String> addresses,
    int? limit,
    int? offset,
  }) async {
    await _ensureStarted();
    final args = <String, dynamic>{'addresses': addresses};
    if (limit != null) args['limit'] = limit;
    if (offset != null) args['offset'] = offset;

    final result = await _sendRequest('fetchTokensPageByAddresses', args);

    final items = result['items'] as List<Object?>? ?? const [];
    final tokens = items
        .whereType<Map<Object?, Object?>>()
        .map(
          (e) => AssetToken.fromRest(Map<String, dynamic>.from(e as Map)),
        )
        .toList(growable: false);
    final nextOffset = result['nextOffset'] as int?;

    return TokensPage(tokens: tokens, nextOffset: nextOffset);
  }

  @override
  Future<AssetToken?> rebuildMetadataAndFetchToken(String cid) async {
    await _ensureStarted();
    final result = await _sendRequest('rebuildMetadataAndFetchToken', {
      'cid': cid,
    });
    final parsed = RebuildMetadataResult.fromJson(
      Map<String, dynamic>.from(result),
    );
    if (parsed is RebuildMetadataFailed) {
      throw Exception(parsed.error);
    }
    return (parsed as RebuildMetadataDone).assetToken;
  }

  Future<Map<String, dynamic>> _sendRequest(
    String op,
    Map<String, dynamic> args,
  ) async {
    if (_sendPort == null) {
      throw StateError(
        'IndexerServiceIsolate not ready. Call start() and await ready.',
      );
    }

    final id = '${++_requestId}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    _sendPort!.send(<Object?>[id, op, args]);

    final raw = await completer.future;

    if (raw['error'] != null) {
      throw Exception(raw['error'] as String);
    }

    return Map<String, dynamic>.from(raw['result'] as Map);
  }

  void _onMessage(dynamic message) {
    if (message is! List || message.length < 2) return;

    final id = message[0] as String?;
    if (id == null) {
      if (message.length >= 2 && message[1] is SendPort) {
        _sendPort = message[1] as SendPort;
        if (!_ready.isCompleted) {
          _ready.complete();
        }
      }
      return;
    }

    final completer = _pending.remove(id);
    if (completer == null) return;

    if (message.length >= 2) {
      final payload = message[1];
      if (payload is Map) {
        completer.complete(Map<String, dynamic>.from(payload));
      } else {
        completer.completeError(StateError('Invalid response payload'));
      }
    } else {
      completer.completeError(StateError('Empty response'));
    }
  }
}

/// Top-level entry point for the isolate. Must be top-level or static.
void _isolateEntry(List<Object?> args) {
  if (args.length < 3) return;

  final mainSendPort = args[0]! as SendPort;
  final endpoint = args[1]! as String;
  final apiKey = args[2]! as String;

  final log = Logger('IndexerServiceIsolate[Isolate]');

  final indexerService = IndexerService(
    client: IndexerClient(
      endpoint: endpoint,
      defaultHeaders: <String, String>{
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'ApiKey $apiKey',
      },
    ),
  );

  final receivePort = ReceivePort();
  receivePort.listen((dynamic message) {
    if (message is! List || message.length < 3) return;

    final id = message[0] as String?;
    final op = message[1] as String?;
    final args = message[2];

    if (id == null || op == null) return;

    Future<Map<String, dynamic>> run() async {
      try {
        switch (op) {
          case 'indexAddressesList':
            final addresses =
                (args is Map? ? args : null)?['addresses'] as List?;
            if (addresses == null || addresses.isEmpty) {
              throw ArgumentError('addresses must not be empty');
            }
            final results = await indexerService.indexAddressesList(
              addresses.cast<String>(),
            );
            return {
              'jobs': results.map((r) => r.toJson()).toList(),
            };

          case 'getAddressIndexingJobStatus':
            final workflowId =
                (args is Map? ? args : null)?['workflowId'] as String?;
            if (workflowId == null || workflowId.isEmpty) {
              throw ArgumentError('workflowId must not be empty');
            }
            final status = await indexerService.getAddressIndexingJobStatus(
              workflowId: workflowId,
            );
            return status.toJson();

          case 'fetchTokensPageByAddresses':
            final map = args is Map? ? args : null;
            final addresses = map?['addresses'] as List?;
            if (addresses == null || addresses.isEmpty) {
              throw ArgumentError('addresses must not be empty');
            }
            final page = await indexerService.fetchTokensPageByAddresses(
              addresses: addresses.cast<String>(),
              limit: map?['limit'] as int?,
              offset: map?['offset'] as int?,
            );
            return {
              'items': page.tokens.map((t) => t.toRestJson()).toList(),
              'nextOffset': page.nextOffset,
            };

          case 'rebuildMetadataAndFetchToken':
            final cid = (args is Map? ? args : null)?['cid'] as String?;
            if (cid == null || cid.isEmpty) {
              throw ArgumentError('cid must not be empty');
            }
            return _rebuildMetadataAndFetchToken(indexerService, cid);

          default:
            throw ArgumentError('Unknown op: $op');
        }
      } catch (e, st) {
        log.warning('Isolate op $op failed', e, st);
        rethrow;
      }
    }

    run().then((result) {
      mainSendPort.send(<Object?>[id, {'result': result}]);
    }).catchError((Object e) {
      mainSendPort.send(<Object?>[id, {'error': e.toString()}]);
    });
  });

  mainSendPort.send(<Object?>[null, receivePort.sendPort]);
}

/// Runs trigger + poll loop + fetch in isolate. Polls every 2-3s, max ~60 times.
/// Returns [RebuildMetadataDone] or [RebuildMetadataFailed]; never throws so
/// main receives structured response via toJson/fromJson across isolate boundary.
Future<Map<String, dynamic>> _rebuildMetadataAndFetchToken(
  IndexerService indexerService,
  String cid,
) async {
  const pollInterval = Duration(seconds: 3);
  const maxPollCount = 60;

  try {
    final result = await indexerService.triggerMetadataIndexing([cid]);
    final workflowId = result.workflowId;
    final runId = result.runId;

    for (var i = 0; i < maxPollCount; i++) {
      final status = await indexerService.getWorkflowStatus(
        workflowId: workflowId,
        runId: runId,
      );
      if (status.isTerminal) {
        if (!status.isSuccess) {
          return RebuildMetadataFailed(
            error: 'Metadata rebuild failed: workflow status ${status.status}',
          ).toJson();
        }
        final token = await indexerService.getTokenByCid(cid);
        if (token == null) {
          return const RebuildMetadataFailed(
            error: 'Token not found after metadata rebuild',
          ).toJson();
        }
        return RebuildMetadataDone(token: token.toRestJson()).toJson();
      }
      await Future<void>.delayed(pollInterval);
    }
    return RebuildMetadataFailed(
      error: 'Metadata rebuild timed out after $maxPollCount polls',
    ).toJson();
  } on Object catch (e) {
    return RebuildMetadataFailed(error: e.toString()).toJson();
  }
}
