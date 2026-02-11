import 'dart:async';
import 'dart:collection';

import 'package:graphql/client.dart';
import 'package:sentry/sentry.dart';

/// GraphQL client for the indexer service.
/// Handles fetching tokens from the indexer API.
class IndexerClient {
  /// Creates an IndexerClient.
  IndexerClient({
    required String endpoint,
    this.defaultHeaders = const {},
    this.queryTimeout = const Duration(seconds: 60),
    this.mutationTimeout = const Duration(seconds: 15),
    this.maxConcurrentRequests = 4,
    this.maxRequestsPerSecond = 4,
  }) : _client = GraphQLClient(
         link: HttpLink(
           '${endpoint}/graphql',
           defaultHeaders: defaultHeaders,
         ),
         cache: GraphQLCache(),
       ),
       _availableRequests = maxRequestsPerSecond {
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

  final Queue<_QueuedIndexerRequest<dynamic>> _pendingRequests =
      Queue<_QueuedIndexerRequest<dynamic>>();
  late final Timer _rateLimitWindowTimer;
  int _activeRequests = 0;
  int _availableRequests;
  bool _isDisposed = false;

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
      try {
        final result = await _client.query(
          QueryOptions(
            document: gql(doc),
            variables: vars,
            fetchPolicy: FetchPolicy.networkOnly,
            queryRequestTimeout: queryTimeout,
          ),
        );

        if (result.hasException) {
          _captureGraphQLError(
            operation: 'query',
            doc: doc,
            vars: vars,
            exception: result.exception,
          );
          throw Exception('GraphQL error: ${result.exception}');
        }

        final data = result.data;
        if (data == null) return null;
        if (subKey == null) return Map<String, dynamic>.from(data);

        final value = data[subKey];
        return value is Map<String, dynamic>
            ? value
            : Map<String, dynamic>.from(data);
      } catch (e, stack) {
        _captureUnhandledError(
          operation: 'query',
          doc: doc,
          vars: vars,
          error: e,
          stackTrace: stack,
        );
        rethrow;
      }
    });
  }

  /// Executes a raw GraphQL mutation.
  Future<Map<String, dynamic>?> mutate({
    required String doc,
    Map<String, dynamic> vars = const {},
    String? subKey,
  }) async {
    return _enqueue<Map<String, dynamic>?>(() async {
      try {
        final result = await _client
            .mutate(
              MutationOptions(
                document: gql(doc),
                variables: vars,
                fetchPolicy: FetchPolicy.networkOnly,
                queryRequestTimeout: mutationTimeout,
              ),
            )
            .timeout(mutationTimeout);

        if (result.hasException) {
          _captureGraphQLError(
            operation: 'mutation',
            doc: doc,
            vars: vars,
            exception: result.exception,
          );
          throw Exception('GraphQL error: ${result.exception}');
        }

        final data = result.data;
        if (data == null) return null;
        if (subKey == null) return Map<String, dynamic>.from(data);

        final value = data[subKey];
        return value is Map<String, dynamic>
            ? value
            : Map<String, dynamic>.from(data);
      } catch (e, stack) {
        _captureUnhandledError(
          operation: 'mutation',
          doc: doc,
          vars: vars,
          error: e,
          stackTrace: stack,
        );
        rethrow;
      }
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

  void _captureGraphQLError({
    required String operation,
    required String doc,
    required Map<String, dynamic> vars,
    required OperationException? exception,
  }) {
    try {
      Sentry.captureEvent(
        SentryEvent(
          message: SentryMessage('IndexerClient $operation GraphQL exception'),
          level: SentryLevel.error,
          tags: {
            'layer': 'infra/graphql',
            'operation': operation,
          },
          extra: {
            'vars': vars,
            'doc': doc,
            'graphqlErrors': exception?.graphqlErrors
                .map((e) => e.message)
                .toList(),
            'linkException': exception?.linkException?.toString(),
          },
          throwable: exception,
        ),
      );
    } catch (_) {
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
      Sentry.captureEvent(
        SentryEvent(
          message: SentryMessage('IndexerClient $operation failed'),
          level: SentryLevel.error,
          tags: {
            'layer': 'infra/graphql',
            'operation': operation,
          },
          extra: {
            'vars': vars,
            'doc': doc,
          },
          throwable: error,
        ),
      );
    } catch (_) {
      // Avoid cascading failures from error reporting.
    }
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
