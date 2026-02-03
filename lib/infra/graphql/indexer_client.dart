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
  }) : _client = GraphQLClient(
          link: HttpLink(
            endpoint,
            defaultHeaders: defaultHeaders,
          ),
          cache: GraphQLCache(),
        );

  final GraphQLClient _client;

  /// Default headers for requests.
  final Map<String, String> defaultHeaders;

  /// Default timeout for GraphQL queries.
  final Duration queryTimeout;

  /// Default timeout for GraphQL mutations.
  final Duration mutationTimeout;

  /// Executes a raw GraphQL query.
  ///
  /// This is used by higher-level services to implement additional operations
  /// (e.g. changes/workflow queries) without duplicating client wiring.
  Future<Map<String, dynamic>?> query({
    required String doc,
    Map<String, dynamic> vars = const {},
    String? subKey,
  }) async {
    try {
      final result = await _client
          .query(
            QueryOptions(
              document: gql(doc),
              variables: vars,
              fetchPolicy: FetchPolicy.networkOnly,
            ),
          )
          .timeout(queryTimeout);

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
  }

  /// Executes a raw GraphQL mutation.
  Future<Map<String, dynamic>?> mutate({
    required String doc,
    Map<String, dynamic> vars = const {},
    String? subKey,
  }) async {
    try {
      final result = await _client
          .mutate(
            MutationOptions(
              document: gql(doc),
              variables: vars,
              fetchPolicy: FetchPolicy.networkOnly,
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
            'graphqlErrors':
                exception?.graphqlErrors.map((e) => e.message).toList(),
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
