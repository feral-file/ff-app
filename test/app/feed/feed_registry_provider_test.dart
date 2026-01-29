import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/app/feed/curated_channel_urls.dart';
import 'package:app/app/feed/feed_registry_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/dp1_feed_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/storage/feed_server_prefs_store.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryFeedServerPrefsStore extends FeedServerPrefsStore {
  _InMemoryFeedServerPrefsStore()
      : super(documentsDirFactory: () async => Directory.systemTemp);

  final List<String> _urls = <String>[];

  @override
  Future<List<String>> readCustomBaseUrls() async {
    return List<String>.unmodifiable(_urls);
  }

  @override
  Future<void> writeCustomBaseUrls(List<String> baseUrls) async {
    _urls
      ..clear()
      ..addAll(baseUrls);
  }

  @override
  Future<void> addCustomBaseUrl(String baseUrl) async {
    if (_urls.contains(baseUrl)) return;
    _urls
      ..add(baseUrl)
      ..sort();
  }

  @override
  Future<void> removeCustomBaseUrl(String baseUrl) async {
    _urls.remove(baseUrl);
  }
}

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
  test('build() loads curated URLs and custom baseUrls from store', () async {
    final prefs = _InMemoryFeedServerPrefsStore();
    await prefs.writeCustomBaseUrls(<String>['https://custom.example']);

    final container = ProviderContainer.test(
      overrides: [
        feedServerPrefsStoreProvider.overrideWithValue(prefs),
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

    expect(state.customFeedServerBaseUrls, equals(<String>['https://custom.example']));
  });

  test('addCustomServer normalizes origin and persists', () async {
    final prefs = _InMemoryFeedServerPrefsStore();

    final container = ProviderContainer.test(
      overrides: [
        feedServerPrefsStoreProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container.read(feedRegistryProvider.notifier).addCustomServer(
          'https://custom.example/some/path',
        );

    final state = await container.read(feedRegistryProvider.future);
    expect(
      state.customFeedServerBaseUrls,
      equals(<String>['https://custom.example']),
    );
  });

  test('bootstrap fetches curated channels + playlists for custom servers',
      () async {
    final prefs = _InMemoryFeedServerPrefsStore();
    await prefs.writeCustomBaseUrls(<String>['https://custom.example']);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);

    final indexerClient = IndexerClient(endpoint: 'http://localhost');
    final indexerService = IndexerService(
      client: indexerClient,
      databaseService: dbService,
    );

    final dio = Dio()
      ..httpClientAdapter = _StubHttpClientAdapter(
        playlistsItems: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'pl_1',
            'title': 'Playlist 1',
            'slug': 'playlist-1',
            'dpVersion': '1',
            'channelId': 'ch_123',
            'signatures': <dynamic>[],
            'defaults': null,
            'dynamicQueries': null,
            'items': <dynamic>[],
          },
        ],
      );

    final dp1FeedService = DP1FeedService(
      databaseService: dbService,
      indexerService: indexerService,
      apiKey: 'test',
      dio: dio,
    );

    final container = ProviderContainer.test(
      overrides: [
        feedServerPrefsStoreProvider.overrideWithValue(prefs),
        curatedDp1ChannelUrlsProvider.overrideWithValue(
          <String>['https://feed.example/api/v1/channels/ch_123'],
        ),
        dp1FeedServiceProvider.overrideWithValue(dp1FeedService),
      ],
    );
    addTearDown(container.dispose);

    final result =
        await container.read(feedRegistryProvider.notifier).bootstrap();

    expect(result.channelsFetched, equals(1));
    // The stub adapter returns the same playlist payload for every feed server.
    // Since bootstrap touches both feed.example and custom.example, it sums up.
    expect(result.playlistsFetched, equals(2));
    expect(
      result.feedServersTouched,
      equals(2),
    ); // feed.example + custom.example

    final playlists = await dbService.getAllPlaylists();
    expect(playlists.any((p) => p.id == 'pl_1'), isTrue);
  });
}
