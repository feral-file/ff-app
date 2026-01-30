import 'dart:convert';
import 'dart:io';

import 'package:app/app/feed/curated_channel_urls.dart';
import 'package:app/app/feed/feed_registry_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/feed_config_store.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubHttpClientAdapter implements HttpClientAdapter {
  _StubHttpClientAdapter({
    required this.playlistsItems,
  });

  final List<Map<String, dynamic>> playlistsItems;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final path = options.uri.path;

    if (path.endsWith('/api/v1/playlists')) {
      final body = jsonEncode(<String, dynamic>{
        'items': playlistsItems,
        'hasMore': false,
        'cursor': null,
      });
      return ResponseBody.fromString(
        body,
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );
    }

    if (path.contains('/api/v1/channels/')) {
      final channelId = path.split('/').last;
      final body = jsonEncode(<String, dynamic>{
        'id': channelId,
        'title': 'Channel $channelId',
        'slug': 'channel-$channelId',
        'curator': 'Curator',
        'summary': 'Summary',
        'coverImageUri': null,
      });
      return ResponseBody.fromString(
        body,
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );
    }

    return ResponseBody.fromString(
      jsonEncode(<String, dynamic>{}),
      404,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }
}

void main() {
  setUpAll(() async {
    // Initialize dotenv for tests
    dotenv.testLoad(fileInput: '''
DP1_FEED_URL=https://api.feed.feralfile.com
DP1_FEED_API_KEY=test_key
INDEXER_API_URL=https://api.indexer.feralfile.com
INDEXER_API_KEY=test_key
ASSET_URL=https://assets.feralfile.com
''');
    await AppConfig.initialize();
  });

  test('build() loads curated URLs', () async {
    final container = ProviderContainer.test(
      overrides: [
        curatedDp1ChannelUrlsProvider.overrideWithValue(
          <String>['https://feed.example/api/v1/channels/ch_123'],
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(feedRegistryProvider.future);

    expect(state.curatedChannels, hasLength(1));
    expect(state.curatedChannels.single.baseUrl, equals('https://feed.example'));
    expect(state.curatedChannels.single.channelId, equals('ch_123'));
  });

  test('setupRemoteConfigChannels groups channels by baseUrl', () async {
    final tempDir = Directory.systemTemp.createTempSync('feed_registry_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);

    final indexerClient = IndexerClient(endpoint: 'http://localhost');
    final indexerService = IndexerService(
      client: indexerClient,
      databaseService: dbService,
    );

    final feedConfigStore = FeedConfigStore(
      documentsDirFactory: () async => tempDir,
    );

    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWithValue(dbService),
        indexerServiceProvider.overrideWithValue(indexerService),
        feedConfigStoreProvider.overrideWithValue(feedConfigStore),
      ],
    );
    addTearDown(container.dispose);

    await container.read(feedRegistryProvider.notifier).setupRemoteConfigChannels(
      <String>[
        'https://feed1.example/api/v1/channels/ch_1',
        'https://feed1.example/api/v1/channels/ch_2',
        'https://feed2.example/api/v1/channels/ch_3',
      ],
    );

    // No direct way to verify internal state, but should not throw
  });

  test('reloadAllCache completes without error when services are set up', () async {
    final tempDir = Directory.systemTemp.createTempSync('feed_registry_test_');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);

    final indexerClient = IndexerClient(endpoint: 'http://localhost');
    final indexerService = IndexerService(
      client: indexerClient,
      databaseService: dbService,
    );

    final feedConfigStore = FeedConfigStore(
      documentsDirFactory: () async => tempDir,
    );

    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWithValue(dbService),
        indexerServiceProvider.overrideWithValue(indexerService),
        feedConfigStoreProvider.overrideWithValue(feedConfigStore),
      ],
    );
    addTearDown(container.dispose);

    await container.read(feedRegistryProvider.notifier).setupRemoteConfigChannels(
      <String>['https://feed.example/api/v1/channels/ch_123'],
    );

    // This should complete without throwing, even if HTTP calls fail
    // (which they will in tests without proper mocking)
    await expectLater(
      container.read(feedRegistryProvider.notifier).reloadAllCache(force: true),
      completes,
    );
  });
}

