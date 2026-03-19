import 'dart:async';
import 'dart:io';

import 'package:app/infra/graphql/indexer_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql/client.dart';
import 'package:http/http.dart' show ClientException;
import 'package:sentry/sentry.dart';

void main() {
  group('IndexerClient Sentry filtering', () {
    test(
      'query skips Sentry capture for transient network link failures',
      () async {
        final capturedEvents = <SentryEvent>[];
        final client = IndexerClient(
          endpoint: 'https://example.invalid',
          client: _buildClient(
            handler: (_) => Stream<Response>.error(
              ServerException(
                originalException: ClientException(
                  'Bad file descriptor',
                  Uri.parse('https://example.invalid/graphql'),
                ),
              ),
            ),
          ),
          sentryCaptureEvent: (event) async {
            capturedEvents.add(event);
            return const SentryId.empty();
          },
        );

        await expectLater(
          client.query(
            doc: 'query TestOperation { viewer { id } }',
            vars: const {'owner': '0x123'},
          ),
          throwsA(isA<Exception>()),
        );
        await Future<void>.delayed(Duration.zero);

        expect(capturedEvents, isEmpty);

        client.dispose();
      },
    );

    test(
      'mutation skips Sentry capture for transient network link failures',
      () async {
        final capturedEvents = <SentryEvent>[];
        final client = IndexerClient(
          endpoint: 'https://example.invalid',
          client: _buildClient(
            handler: (_) => Stream<Response>.error(
              NetworkException.fromException(
                originalException: const SocketException('Connection refused'),
                originalStackTrace: StackTrace.current,
                uri: Uri.parse('https://example.invalid/graphql'),
              ),
            ),
          ),
          sentryCaptureEvent: (event) async {
            capturedEvents.add(event);
            return const SentryId.empty();
          },
        );

        await expectLater(
          client.mutate(
            doc: 'mutation TestMutation { triggerMetadataIndexing }',
            vars: const {'owner': '0x123'},
          ),
          throwsA(isA<Exception>()),
        );
        await Future<void>.delayed(Duration.zero);

        expect(capturedEvents, isEmpty);

        client.dispose();
      },
    );

    test('query captures Sentry event for GraphQL response errors', () async {
      final capturedEvents = <SentryEvent>[];
      final client = IndexerClient(
        endpoint: 'https://example.invalid',
        client: _buildClient(
          handler: (_) => Stream<Response>.value(
            const Response(
              errors: [
                GraphQLError(message: 'Unauthorized'),
              ],
              response: {
                'errors': [
                  {'message': 'Unauthorized'},
                ],
              },
            ),
          ),
        ),
        sentryCaptureEvent: (event) async {
          capturedEvents.add(event);
          return const SentryId.empty();
        },
      );

      await expectLater(
        client.query(
          doc: 'query TestOperation { viewer { id } }',
          vars: const {'owner': '0x123'},
        ),
        throwsA(isA<Exception>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(capturedEvents, hasLength(1));
      expect(
        capturedEvents.single.message?.formatted,
        'IndexerClient query GraphQL exception',
      );
      expect(capturedEvents.single.level, SentryLevel.error);

      client.dispose();
    });
  });
}

GraphQLClient _buildClient({
  required Stream<Response> Function(Request request) handler,
}) {
  return GraphQLClient(
    link: Link.function((request, [forward]) => handler(request)),
    cache: GraphQLCache(),
  );
}
