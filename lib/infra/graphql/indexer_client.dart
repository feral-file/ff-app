import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:app/infra/logging/log_sanitizer.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:graphql/client.dart';
import 'package:http/http.dart';
import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';
import 'package:sentry_link/sentry_link.dart';

/// Injectable Sentry capture hook so tests can verify reporting decisions
/// without depending on the global Sentry client.
typedef IndexerSentryCapture = Future<SentryId> Function(SentryEvent event);

/// GraphQL client for the indexer service.
/// Handles fetching tokens from the indexer API.
class IndexerClient {
  /// Creates an IndexerClient.
  IndexerClient({
    required String endpoint,
    this.defaultHeaders = const {},
    this.queryTimeout = const Duration(seconds: 60),
    this.mutationTimeout = const Duration(seconds: 15),
    this.maxConcurrentRequests = 10,
    this.maxRequestsPerSecond = 10,
    GraphQLClient? client,
    IndexerSentryCapture? sentryCaptureEvent,
    Logger? logger,
  }) : _client =
           client ??
           _createClient(
             endpoint: endpoint,
             defaultHeaders: defaultHeaders,
           ),
       _availableRequests = maxRequestsPerSecond,
       _captureSentryEvent = sentryCaptureEvent ?? Sentry.captureEvent,
       _structuredLog = AppStructuredLog.forLogger(
         logger ?? Logger('IndexerClient'),
         context: {
           'layer': 'infra/graphql',
           'client': 'indexer',
         },
       ) {
    _rateLimitWindowTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _onRateLimitWindowReset(),
    );
  }

  final GraphQLClient _client;

  /// Default headers for requests.
  final Map<String, String> defaultHeaders;

  /// Default timeout for GraphQL queries.
  final Duration queryTimeout;

  /// Default timeout for GraphQL mutations.
  final Duration mutationTimeout;

  /// Max in-flight requests allowed at once.
  final int maxConcurrentRequests;

  /// Max requests allowed to start per second.
  final int maxRequestsPerSecond;
  final IndexerSentryCapture _captureSentryEvent;
  final StructuredLogger _structuredLog;

  final Queue<_QueuedIndexerRequest<dynamic>> _pendingRequests =
      Queue<_QueuedIndexerRequest<dynamic>>();
  late final Timer _rateLimitWindowTimer;
  int _activeRequests = 0;
  int _availableRequests;
  bool _isDisposed = false;

  static GraphQLClient _createClient({
    required String endpoint,
    required Map<String, String> defaultHeaders,
  }) {
    return GraphQLClient(
      link: Link.from([
        SentryGql.link(
          shouldStartTransaction: true,
          graphQlErrorsMarkTransactionAsFailed: true,
        ),
        HttpLink(
          '$endpoint/graphql',
          defaultHeaders: defaultHeaders,
        ),
      ]),
      cache: GraphQLCache(),
    );
  }

  /// Executes a raw GraphQL query.
  ///
  /// This is used by higher-level services to implement additional operations
  /// (e.g. changes/workflow queries) without duplicating client wiring.
  Future<Map<String, dynamic>?> query({
    required String doc,
    Map<String, dynamic> vars = const {},
    String? subKey,
  }) async {
    return _enqueue<Map<String, dynamic>?>(() async {
      final operation = _extractOperationDescriptor(
        doc,
        defaultType: 'query',
      );
      final stopwatch = Stopwatch()..start();
      _structuredLog.info(
        category: LogCategory.graphql,
        event: 'graphql_operation_started',
        message: 'query ${operation.name} started',
        payload: {
          'operationType': operation.type,
          'operationName': operation.name,
          'variables': LogSanitizer.sanitizeGraphqlVariables(vars),
        },
      );
      final QueryResult result;
      try {
        result = await _client.query(
          QueryOptions(
            document: gql(doc),
            variables: vars,
            fetchPolicy: FetchPolicy.networkOnly,
            queryRequestTimeout: queryTimeout,
          ),
        );
      } catch (e, stack) {
        _structuredLog.error(
          event: 'graphql_operation_failed',
          message:
              'query ${operation.name} failed durationMs='
              '${stopwatch.elapsedMilliseconds}',
          error: e,
          stackTrace: stack,
          payload: {
            'operationType': operation.type,
            'operationName': operation.name,
            'durationMs': stopwatch.elapsedMilliseconds,
            'variables': LogSanitizer.sanitizeGraphqlVariables(vars),
            'error': LogSanitizer.sanitizeError(e),
          },
        );
        _captureUnhandledError(
          operation: 'query',
          doc: doc,
          vars: vars,
          error: e,
          stackTrace: stack,
        );
        rethrow;
      }

      if (result.hasException) {
        _structuredLog.error(
          event: 'graphql_operation_failed',
          message:
              'query ${operation.name} failed durationMs='
              '${stopwatch.elapsedMilliseconds}',
          error: result.exception,
          payload: {
            'operationType': operation.type,
            'operationName': operation.name,
            'durationMs': stopwatch.elapsedMilliseconds,
            'variables': LogSanitizer.sanitizeGraphqlVariables(vars),
            'error': _sanitizeGraphqlException(result.exception),
          },
        );
        _captureGraphQLError(
          operation: 'query',
          doc: doc,
          vars: vars,
          exception: result.exception,
        );
        throw Exception('GraphQL error: ${result.exception}');
      }

      final data = result.data;
      _structuredLog.info(
        category: LogCategory.graphql,
        event: 'graphql_operation_completed',
        message:
            'query ${operation.name} completed durationMs='
            '${stopwatch.elapsedMilliseconds}',
        payload: {
          'operationType': operation.type,
          'operationName': operation.name,
          'durationMs': stopwatch.elapsedMilliseconds,
          'hasData': data != null,
        },
      );
      if (data == null) return null;
      if (subKey == null) return Map<String, dynamic>.from(data);

      final value = data[subKey];
      return value is Map<String, dynamic>
          ? value
          : Map<String, dynamic>.from(data);
    });
  }

  /// Executes a raw GraphQL mutation.
  Future<Map<String, dynamic>?> mutate({
    required String doc,
    Map<String, dynamic> vars = const {},
    String? subKey,
  }) async {
    return _enqueue<Map<String, dynamic>?>(() async {
      final operation = _extractOperationDescriptor(
        doc,
        defaultType: 'mutation',
      );
      final stopwatch = Stopwatch()..start();
      _structuredLog.info(
        category: LogCategory.graphql,
        event: 'graphql_operation_started',
        message: 'mutation ${operation.name} started',
        payload: {
          'operationType': operation.type,
          'operationName': operation.name,
          'variables': LogSanitizer.sanitizeGraphqlVariables(vars),
        },
      );
      final QueryResult result;
      try {
        result = await _client
            .mutate(
              MutationOptions(
                document: gql(doc),
                variables: vars,
                fetchPolicy: FetchPolicy.networkOnly,
                queryRequestTimeout: mutationTimeout,
              ),
            )
            .timeout(mutationTimeout);
      } catch (e, stack) {
        _structuredLog.error(
          event: 'graphql_operation_failed',
          message:
              'mutation ${operation.name} failed durationMs='
              '${stopwatch.elapsedMilliseconds}',
          error: e,
          stackTrace: stack,
          payload: {
            'operationType': operation.type,
            'operationName': operation.name,
            'durationMs': stopwatch.elapsedMilliseconds,
            'variables': LogSanitizer.sanitizeGraphqlVariables(vars),
            'error': LogSanitizer.sanitizeError(e),
          },
        );
        _captureUnhandledError(
          operation: 'mutation',
          doc: doc,
          vars: vars,
          error: e,
          stackTrace: stack,
        );
        rethrow;
      }

      if (result.hasException) {
        _structuredLog.error(
          event: 'graphql_operation_failed',
          message:
              'mutation ${operation.name} failed durationMs='
              '${stopwatch.elapsedMilliseconds}',
          error: result.exception,
          payload: {
            'operationType': operation.type,
            'operationName': operation.name,
            'durationMs': stopwatch.elapsedMilliseconds,
            'variables': LogSanitizer.sanitizeGraphqlVariables(vars),
            'error': _sanitizeGraphqlException(result.exception),
          },
        );
        _captureGraphQLError(
          operation: 'mutation',
          doc: doc,
          vars: vars,
          exception: result.exception,
        );
        throw Exception('GraphQL error: ${result.exception}');
      }

      final data = result.data;
      _structuredLog.info(
        category: LogCategory.graphql,
        event: 'graphql_operation_completed',
        message:
            'mutation ${operation.name} completed durationMs='
            '${stopwatch.elapsedMilliseconds}',
        payload: {
          'operationType': operation.type,
          'operationName': operation.name,
          'durationMs': stopwatch.elapsedMilliseconds,
          'hasData': data != null,
        },
      );
      if (data == null) return null;
      if (subKey == null) return Map<String, dynamic>.from(data);

      final value = data[subKey];
      return value is Map<String, dynamic>
          ? value
          : Map<String, dynamic>.from(data);
    });
  }

  /// Frees timers/resources and fails outstanding queued requests.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _rateLimitWindowTimer.cancel();

    while (_pendingRequests.isNotEmpty) {
      final queued = _pendingRequests.removeFirst();
      if (!queued.completer.isCompleted) {
        queued.completer.completeError(
          StateError('IndexerClient disposed before request was sent'),
        );
      }
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    if (_isDisposed) {
      return Future<T>.error(
        StateError('IndexerClient is disposed'),
      );
    }

    final completer = Completer<T>();
    _pendingRequests.add(
      _QueuedIndexerRequest<T>(
        operation: operation,
        completer: completer,
      ),
    );
    _drainQueue();
    return completer.future;
  }

  void _onRateLimitWindowReset() {
    if (_isDisposed) return;
    _availableRequests = maxRequestsPerSecond;
    _drainQueue();
  }

  void _drainQueue() {
    if (_isDisposed) return;

    while (_pendingRequests.isNotEmpty &&
        _activeRequests < maxConcurrentRequests &&
        _availableRequests > 0) {
      final queued = _pendingRequests.removeFirst();
      _activeRequests += 1;
      _availableRequests -= 1;
      unawaited(_runQueued(queued));
    }
  }

  Future<void> _runQueued<T>(_QueuedIndexerRequest<T> queued) async {
    try {
      final value = await queued.operation();
      if (!queued.completer.isCompleted) {
        queued.completer.complete(value);
      }
    } catch (e, stack) {
      if (!queued.completer.isCompleted) {
        queued.completer.completeError(e, stack);
      }
    } finally {
      _activeRequests -= 1;
      _drainQueue();
    }
  }

  bool _shouldCaptureGraphQlException(OperationException? exception) {
    if (exception == null) return true;
    if (exception.graphqlErrors.isNotEmpty) return true;

    final linkException = exception.linkException;
    if (linkException == null) return true;
    if (linkException is NetworkException) return false;

    final originalException = linkException.originalException;
    if (originalException is ClientException ||
        originalException is SocketException) {
      return false;
    }

    // We suppress known transport-level failures here so transient connectivity
    // during startup does not become Sentry error noise. GraphQL/schema errors
    // still report because those indicate server or client contract issues.
    final combinedMessage = '$linkException ${originalException ?? ''}'
        .toLowerCase();
    const transportFailureMarkers = <String>[
      'bad file descriptor',
      'connection reset',
      'connection refused',
      'failed host lookup',
      'network is unreachable',
      'software caused connection abort',
      'connection closed before full header was received',
      'timed out',
    ];
    return !transportFailureMarkers.any(combinedMessage.contains);
  }

  void _captureGraphQLError({
    required String operation,
    required String doc,
    required Map<String, dynamic> vars,
    required OperationException? exception,
  }) {
    if (!_shouldCaptureGraphQlException(exception)) {
      return;
    }

    try {
      unawaited(
        _captureSentryEvent(
          SentryEvent(
            message: SentryMessage(
              'IndexerClient $operation GraphQL exception',
            ),
            level: SentryLevel.error,
            tags: {
              'layer': 'infra/graphql',
              'operation': operation,
            },
            contexts: Contexts()
              ..['indexer_graphql'] = {
                'vars': vars,
                'doc': doc,
                'graphqlErrors': exception?.graphqlErrors
                    .map((e) => e.message)
                    .toList(),
                'linkException': exception?.linkException?.toString(),
              },
            throwable: exception,
          ),
        ),
      );
    } on Object catch (_) {
      // Avoid cascading failures from error reporting.
    }
  }

  void _captureUnhandledError({
    required String operation,
    required String doc,
    required Map<String, dynamic> vars,
    required Object error,
    required StackTrace stackTrace,
  }) {
    try {
      unawaited(
        _captureSentryEvent(
          SentryEvent(
            message: SentryMessage('IndexerClient $operation failed'),
            level: SentryLevel.error,
            tags: {
              'layer': 'infra/graphql',
              'operation': operation,
            },
            contexts: Contexts()
              ..['indexer_graphql'] = {
                'vars': vars,
                'doc': doc,
              },
            throwable: error,
          ),
        ),
      );
    } on Object catch (_) {
      // Avoid cascading failures from error reporting.
    }
  }

  _GraphqlOperationDescriptor _extractOperationDescriptor(
    String doc, {
    required String defaultType,
  }) {
    final pattern = RegExp(
      r'^\s*(query|mutation|subscription)\s+([A-Za-z0-9_]+)?',
      multiLine: true,
      caseSensitive: false,
    );
    final match = pattern.firstMatch(doc);
    final type = (match?.group(1)?.toLowerCase() ?? defaultType).trim();
    final name = (match?.group(2)?.trim().isNotEmpty ?? false)
        ? match!.group(2)!.trim()
        : 'anonymous';
    return _GraphqlOperationDescriptor(type: type, name: name);
  }

  Map<String, dynamic> _sanitizeGraphqlException(
    OperationException? exception,
  ) {
    if (exception == null) {
      return {'type': 'OperationException', 'message': 'null'};
    }

    return {
      'type': 'OperationException',
      'graphqlErrors': exception.graphqlErrors
          .map((error) => error.message)
          .toList(growable: false),
      'linkException': exception.linkException?.toString(),
    };
  }
}

class _QueuedIndexerRequest<T> {
  _QueuedIndexerRequest({
    required this.operation,
    required this.completer,
  });

  final Future<T> Function() operation;
  final Completer<T> completer;
}

class _GraphqlOperationDescriptor {
  const _GraphqlOperationDescriptor({
    required this.type,
    required this.name,
  });

  final String type;
  final String name;
}
