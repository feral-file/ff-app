// ignore_for_file: public_member_api_docs, avoid_catches_without_on_clauses, cast_nullable_to_non_nullable, deprecated_member_use, unintended_html_in_doc_comment, noop_primitive_operations, unnecessary_breaks, omit_local_variable_types // Reason: isolate wire protocol + error reporting mirrors legacy app; keep stable and auditable.

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:app/domain/models/indexer/changes/change.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/indexer/isolate/worker_messages.dart';
import 'package:app/infra/indexer/isolate/worker_tasks.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';

/// Isolate-backed worker that mirrors the old repo's tokens_service isolate.
///
/// Responsibilities (in isolate):
/// - Fetch paged tokens for owner addresses (stream results)
/// - Fetch change journal pages (stream pages)
/// - Trigger indexing operations (addresses, tokens)
///
/// Responsibilities (in main isolate, via coordinator):
/// - Ingest/delete DB
/// - Persist anchors/workflow IDs/last fetch time
/// - TokenIds/tokenCids extraction + delete-missing semantics
class IndexerTokensWorker {
  IndexerTokensWorker({
    required this.endpoint,
    required this.apiKey,
    Logger? logger,
  }) : _log = logger ?? Logger('IndexerTokensWorker');

  final String endpoint;
  final String apiKey;
  final Logger _log;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  ReceivePort? _errorPort;
  ReceivePort? _exitPort;
  SendPort? _sendPort;

  final _ready = Completer<void>();
  final _messages = StreamController<TokensWorkerMessage>.broadcast();

  /// Stream of messages emitted from isolate -> main isolate.
  Stream<TokensWorkerMessage> get messages => _messages.stream;

  /// Resolves once handshake is complete and isolate send port is available.
  Future<void> get ready => _ready.future;

  bool get isRunning => _isolate != null;

  Future<void> start() async {
    if (_isolate != null) return;

    _receivePort = ReceivePort();
    _errorPort = ReceivePort();
    _exitPort = ReceivePort();

    _receivePort!.listen(_handleMainMessage);
    _errorPort!.listen(_handleMainError);
    _exitPort!.listen(_handleMainExit);

    _isolate = await Isolate.spawn<List<Object?>>(
      _isolateEntry,
      <Object?>[
        _receivePort!.sendPort,
        endpoint,
        apiKey,
      ],
      errorsAreFatal: false,
      onError: _errorPort!.sendPort,
      onExit: _exitPort!.sendPort,
    );

    // Wait for handshake. 30 seconds accommodates iOS simulator which can
    // experience significant scheduling delays when multiple isolates start
    // concurrently during app initialisation.
    await ready.timeout(const Duration(seconds: 30));
  }

  void sendRaw(List<Object?> message) {
    if (_sendPort == null) {
      throw StateError('Worker not ready. Call start() and await ready.');
    }
    _sendPort!.send(message);
  }

  /// Start streaming tokens for [addresses] using paging (offset/size).
  void fetchAllTokens({
    required String uuid,
    required List<String> addresses,
    int? offset,
    int? size,
  }) {
    sendRaw(<Object?>[
      WorkerOpcodes.fetchAllTokens,
      uuid,
      addresses,
      offset,
      size,
    ]);
  }

  /// Trigger address indexing for [addresses].
  void reindexAddressesList({
    required String uuid,
    required List<String> addresses,
  }) {
    sendRaw(<Object?>[
      WorkerOpcodes.reindexAddressesList,
      uuid,
      addresses,
    ]);
  }

  /// Stream change-journal pages for [addressAnchors].
  ///
  /// We keep the old repo wire format: a Map<String, String> (address -> json).
  void updateTokensInIsolate({
    required String uuid,
    required List<AddressAnchor> addressAnchors,
  }) {
    final map = <String, String>{
      for (final a in addressAnchors) a.address: a.toJsonString(),
    };

    sendRaw(<Object?>[
      WorkerOpcodes.updateTokensInIsolate,
      uuid,
      map,
    ]);
  }

  /// Fetch tokens by CID list inside isolate.
  ///
  /// Kept for back-compat with legacy flows.
  void fetchManualTokens({
    required String uuid,
    required List<String> tokenCids,
  }) {
    sendRaw(<Object?>[
      WorkerOpcodes.fetchManualTokens,
      uuid,
      tokenCids,
    ]);
  }

  /// Notify isolate that new channel data has been ingested.
  void notifyChannelIngested({required String uuid}) {
    sendRaw(<Object?>[
      WorkerOpcodes.channelIngested,
      uuid,
    ]);
  }

  Future<void> stop() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;

    _sendPort = null;
    _receivePort?.close();
    _errorPort?.close();
    _exitPort?.close();

    if (!_messages.isClosed) {
      await _messages.close();
    }
  }

  void _handleMainMessage(dynamic message) {
    if (message is SendPort) {
      _sendPort = message;
      if (!_ready.isCompleted) _ready.complete();
      return;
    }

    if (message is TokensWorkerMessage) {
      _messages.add(message);
      return;
    }

    // Zone-body errors from the isolate arrive as strings before the handshake
    // SendPort is ever sent. Complete _ready with an error so start() fails
    // fast (instead of waiting the full timeout) and the error is surfaced.
    if (message is String && message.startsWith('UNHANDLED_ERROR:')) {
      _log.warning('Isolate reported: $message');
      if (!_ready.isCompleted) {
        _ready.completeError(StateError(message));
      }
      return;
    }

    _log.warning('Unknown message from isolate: $message');
  }

  void _handleMainError(dynamic message) {
    _log.warning('Isolate error: $message');
  }

  void _handleMainExit(dynamic message) {
    _log.info('Isolate exited.');
  }

  // ---------------------
  // Isolate implementation
  // ---------------------

  static SendPort? _isolateSendPort;
  static late Logger _isolateLog;
  static late IndexerService _indexerService;

  static void _isolateEntry(List<Object?> args) {
    runZonedGuarded(
      () {
        final sendPort = args[0] as SendPort;
        final endpoint = args[1] as String;
        final apiKey = args[2] as String;

        _isolateLog = Logger('IndexerTokensWorker[Isolate]');
        _isolateSendPort = sendPort;

        // Setup isolate-scoped IndexerService (no AppConfig/flutter_dotenv here).
        final client = IndexerClient(
          endpoint: endpoint,
          defaultHeaders: <String, String>{
            'Content-Type': 'application/json',
            if (apiKey.isNotEmpty) 'Authorization': 'ApiKey $apiKey',
          },
        );
        _indexerService = IndexerService(client: client);

        final receivePort = ReceivePort()..listen(_handleMessageInIsolate);
        _isolateSendPort?.send(receivePort.sendPort);
      },
      (error, stackTrace) {
        try {
          unawaited(
            Sentry.captureEvent(
              SentryEvent(
                message: SentryMessage(
                  'Unhandled exception in indexer isolate',
                ),
                level: SentryLevel.error,
                extra: {
                  'error': error.toString(),
                  'stackTrace': stackTrace.toString(),
                },
                throwable: error,
              ),
            ),
          );
        } catch (_) {
          // ignore
        }

        try {
          _isolateSendPort?.send('UNHANDLED_ERROR: ${error.toString()}');
        } catch (_) {
          // ignore
        }
      },
    );
  }

  static void _handleMessageInIsolate(dynamic message) {
    try {
      if (message is! List) return;
      final opcode = message[0];
      if (opcode is! String) return;

      switch (opcode) {
        case WorkerOpcodes.fetchAllTokens:
          unawaited(
            _fetchAllTokens(
              uuid: message[1] as String,
              addresses: List<String>.from(message[2] as List),
              offset: message[3] as int?,
              total: message[4] as int?,
            ),
          );
          break;

        case WorkerOpcodes.reindexAddressesList:
          unawaited(
            _reindexAddressesListInIndexer(
              uuid: message[1] as String,
              addresses: List<String>.from(message[2] as List),
            ),
          );
          break;

        case WorkerOpcodes.updateTokensInIsolate:
          final rawMap = Map<String, String>.from(
            (message[2] as Map).map(
              (k, v) => MapEntry(k as String, v as String? ?? ''),
            ),
          );
          final anchors = <AddressAnchor>[];
          for (final jsonStr in rawMap.values) {
            if (jsonStr.trim().isEmpty) continue;
            final decoded = jsonDecode(jsonStr);
            if (decoded is Map) {
              anchors.add(
                AddressAnchor.fromJson(Map<String, dynamic>.from(decoded)),
              );
            }
          }
          unawaited(
            _updateTokensInIsolate(
              uuid: message[1] as String,
              addressAnchors: anchors,
            ),
          );
          break;

        case WorkerOpcodes.fetchManualTokens:
          unawaited(
            _fetchManualTokens(
              uuid: message[1] as String,
              tokenCids: List<String>.from(message[2] as List),
            ),
          );
          break;

        case WorkerOpcodes.channelIngested:
          _isolateSendPort?.send(ChannelIngestedAck(message[1] as String));
          break;

        default:
          break;
      }
    } catch (e, stack) {
      _isolateLog.warning('Unhandled exception in isolate message handler', e);
      try {
        unawaited(Sentry.captureException(e, stackTrace: stack));
      } catch (_) {}
    }
  }

  static Future<void> _fetchAllTokens({
    required String uuid,
    required List<String> addresses,
    int? offset,
    int? total,
  }) async {
    try {
      if (addresses.isEmpty) {
        _isolateSendPort?.send(FetchTokensSuccess(uuid, addresses));
        return;
      }

      // Legacy behavior: indexerTokensPageSize = 50 in old repo.
      const pageSize = 50;
      var numberOfToken = 0;
      var currentOffset = offset ?? 0;

      while (total == null || numberOfToken < total) {
        final tokens = await _indexerService.fetchTokensByAddresses(
          addresses: addresses,
          limit: pageSize,
          offset: currentOffset,
        );

        if (tokens.isEmpty) break;

        final sentTokens = total == null
            ? tokens
            : tokens
                  .take((total - numberOfToken).clamp(0, tokens.length))
                  .toList();

        _isolateSendPort?.send(FetchTokensData(uuid, addresses, sentTokens));

        currentOffset += sentTokens.length;
        numberOfToken += sentTokens.length;
      }

      _isolateSendPort?.send(FetchTokensSuccess(uuid, addresses));
    } catch (e) {
      _isolateSendPort?.send(FetchTokenFailure(uuid, addresses, e));
    }
  }

  static Future<void> _reindexAddressesListInIndexer({
    required String uuid,
    required List<String> addresses,
  }) async {
    try {
      final results = await _indexerService.indexAddressesList(addresses);
      _isolateSendPort?.send(ReindexAddressesListDone(uuid, results));
    } catch (e) {
      _isolateSendPort?.send(ReindexAddressesFailure(uuid, e));
    }
  }

  static Future<void> _updateTokensInIsolate({
    required String uuid,
    required List<AddressAnchor> addressAnchors,
  }) async {
    final addresses = addressAnchors.map((e) => e.address).toList();
    final anchors = addressAnchors.map((e) => e.anchor).toList();

    try {
      if (addresses.isEmpty) {
        throw Exception('Addresses list cannot be empty');
      }

      final anchor = anchors.isEmpty
          ? null
          : anchors.reduce((a, b) => a < b ? a : b);

      final changesStream = _getChangesForAddresses(
        addresses: addresses,
        anchor: anchor,
      );

      await for (final changesList in changesStream) {
        _isolateSendPort?.send(UpdateTokensData(uuid, changesList, addresses));
      }

      _isolateSendPort?.send(UpdateTokensSuccess(uuid));
    } catch (e) {
      _isolateSendPort?.send(UpdateTokensFailure(uuid, addresses, e));
    }
  }

  static Stream<ChangeList> _getChangesForAddresses({
    required List<String> addresses,
    int? anchor,
  }) async* {
    const pageSize = 50;
    int? nextAnchor = anchor;

    while (true) {
      final req = QueryChangesRequest(
        addresses: addresses,
        limit: pageSize,
        anchor: nextAnchor,
      );

      final page = await _indexerService.getChanges(req);
      if (page.items.isEmpty) break;

      yield page;

      nextAnchor = page.nextAnchor;
      if (nextAnchor == null) break;
    }
  }

  static Future<void> _fetchManualTokens({
    required String uuid,
    required List<String> tokenCids,
  }) async {
    try {
      final tokens = await _indexerService.fetchTokensByCIDs(
        tokenCids: tokenCids,
      );
      _isolateSendPort?.send(FetchManualTokensDone(uuid, tokens));
    } catch (e) {
      _isolateSendPort?.send(FetchManualTokensFailure(uuid, e));
    }
  }
}
