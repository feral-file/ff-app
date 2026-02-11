// ignore_for_file: public_member_api_docs, cast_nullable_to_non_nullable, avoid_catches_without_on_clauses // Reason: isolate wire protocol file intentionally keeps dynamic payload parsing compact.

import 'dart:async';
import 'dart:isolate';

import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:logging/logging.dart';

/// Isolate worker for indexer address indexing trigger + status polling.
class AddressIndexingWorker {
  AddressIndexingWorker({
    required this.endpoint,
    required this.apiKey,
    Logger? logger,
  }) : _log = logger ?? Logger('AddressIndexingWorker');

  final String endpoint;
  final String apiKey;
  final Logger _log;

  Isolate? _isolate;
  ReceivePort? _receivePort;
  ReceivePort? _errorPort;
  ReceivePort? _exitPort;
  SendPort? _sendPort;
  final _ready = Completer<void>();

  final Map<String, Completer<void>> _requestCompleters =
      <String, Completer<void>>{};

  Future<void> get ready => _ready.future;

  Future<void> start() async {
    if (_isolate != null) {
      return;
    }

    _receivePort = ReceivePort()..listen(_handleMainMessage);
    _errorPort = ReceivePort()..listen(_handleMainError);
    _exitPort = ReceivePort()..listen(_handleMainExit);

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

    await ready.timeout(const Duration(seconds: 5));
  }

  Future<void> ensureIndexed({
    required String address,
    Duration timeout = const Duration(minutes: 15),
    Duration pollInterval = const Duration(seconds: 5),
  }) async {
    await ready;

    final uuid = DateTime.now().microsecondsSinceEpoch.toString();
    final completer = Completer<void>();
    _requestCompleters[uuid] = completer;

    _sendPort?.send(<Object?>[
      _AddressIndexingOpcodes.ensureIndexed,
      uuid,
      address,
      timeout.inSeconds,
      pollInterval.inSeconds,
    ]);

    return completer.future;
  }

  Future<void> stop() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    _receivePort?.close();
    _errorPort?.close();
    _exitPort?.close();

    for (final completer in _requestCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('AddressIndexingWorker stopped before completion'),
        );
      }
    }
    _requestCompleters.clear();
  }

  void _handleMainMessage(dynamic message) {
    if (message is SendPort) {
      _sendPort = message;
      if (!_ready.isCompleted) {
        _ready.complete();
      }
      return;
    }

    if (message is! Map<Object?, Object?>) {
      _log.warning('Unknown worker message: $message');
      return;
    }

    final type = message['type']?.toString() ?? '';
    final uuid = message['uuid']?.toString() ?? '';
    if (uuid.isEmpty) {
      return;
    }

    final completer = _requestCompleters.remove(uuid);
    if (completer == null || completer.isCompleted) {
      return;
    }

    if (type == _AddressIndexingMessageType.done) {
      completer.complete();
      return;
    }

    if (type == _AddressIndexingMessageType.failure) {
      completer.completeError(
        Exception(message['error']?.toString() ?? 'Unknown isolate error'),
      );
      return;
    }
  }

  void _handleMainError(dynamic message) {
    _log.warning('Address indexing isolate error: $message');
  }

  void _handleMainExit(dynamic message) {
    _log.info('Address indexing isolate exited');
  }

  static SendPort? _isolateSendPort;
  static late IndexerService _indexerService;

  static void _isolateEntry(List<Object?> args) {
    final sendPort = args[0] as SendPort;
    final endpoint = args[1] as String;
    final apiKey = args[2] as String;

    _isolateSendPort = sendPort;

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
  }

  static void _handleMessageInIsolate(dynamic message) {
    if (message is! List<Object?> || message.isEmpty) {
      return;
    }
    final opcode = message[0]?.toString() ?? '';
    if (opcode != _AddressIndexingOpcodes.ensureIndexed) {
      return;
    }

    final uuid = message[1]?.toString() ?? '';
    final address = message[2]?.toString() ?? '';
    final timeoutSeconds = (message[3] as int?) ?? 900;
    final pollSeconds = (message[4] as int?) ?? 5;

    if (uuid.isEmpty || address.isEmpty) {
      _isolateSendPort?.send(<String, Object>{
        'type': _AddressIndexingMessageType.failure,
        'uuid': uuid,
        'error': 'Invalid ensureIndexed payload',
      });
      return;
    }

    unawaited(
      _ensureIndexedInIsolate(
        uuid: uuid,
        address: address,
        timeout: Duration(seconds: timeoutSeconds),
        pollInterval: Duration(seconds: pollSeconds),
      ),
    );
  }

  static Future<void> _ensureIndexedInIsolate({
    required String uuid,
    required String address,
    required Duration timeout,
    required Duration pollInterval,
  }) async {
    try {
      final results = await _indexerService.indexAddressesList(<String>[
        address,
      ]);

      var workflowId = '';
      for (final result in results) {
        if (_addressesEqual(result.address, address) &&
            result.workflowId.isNotEmpty) {
          workflowId = result.workflowId;
          break;
        }
      }

      if (workflowId.isEmpty) {
        throw Exception('Indexer did not return workflowId for $address');
      }

      final startedAt = DateTime.now();
      while (true) {
        final status = await _indexerService.getAddressIndexingJobStatus(
          workflowId: workflowId,
        );
        if (status.status.isDone) {
          if (!status.status.isSuccess) {
            throw Exception(
              'Indexing finished with ${status.status.name} for $address',
            );
          }
          _isolateSendPort?.send(<String, Object>{
            'type': _AddressIndexingMessageType.done,
            'uuid': uuid,
          });
          return;
        }

        if (DateTime.now().difference(startedAt) > timeout) {
          throw Exception(
            'Timed out waiting for workflow=$workflowId for $address',
          );
        }
        await Future<void>.delayed(pollInterval);
      }
    } catch (e) {
      _isolateSendPort?.send(<String, Object>{
        'type': _AddressIndexingMessageType.failure,
        'uuid': uuid,
        'error': e.toString(),
      });
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
}

abstract final class _AddressIndexingOpcodes {
  static const ensureIndexed = 'ENSURE_INDEXED';
}

abstract final class _AddressIndexingMessageType {
  static const done = 'DONE';
  static const failure = 'FAILURE';
}
