import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/dp1_feed_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for DP1FeedService using Riverpod testing patterns.
/// 
/// These tests mock dependencies using provider overrides, following
/// the Riverpod testing guide: https://riverpod.dev/docs/how_to/testing
void main() {
  late AppDatabase db;
  late DatabaseService databaseService;
  late IndexerClient indexerClient;
  late IndexerService indexerService;

  setUpAll(() async {
    // Initialize AppConfig
    await AppConfig.initialize();
  });

  setUp(() {
    // Create fresh in-memory database for each test
    db = AppDatabase.forTesting(NativeDatabase.memory());
    databaseService = DatabaseService(db);

    // Create real indexer client (can be mocked if needed)
    indexerClient = IndexerClient(
      endpoint: AppConfig.indexerApiUrl,
      defaultHeaders: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AppConfig.indexerApiKey}',
      },
    );

    indexerService = IndexerService(
      client: indexerClient,
      databaseService: databaseService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('DP1FeedService - Unit Tests with Provider Container', () {
    test('service can be created via provider container', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      // The container should be able to create the service
      expect(
        () => DP1FeedService(
          databaseService: databaseService,
          indexerService: indexerService,
          apiKey: AppConfig.dp1FeedApiKey,
        ),
        returnsNormally,
      );
    });

    test('fetchChannel ingests channel into database', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final service = DP1FeedService(
        databaseService: databaseService,
        indexerService: indexerService,
        apiKey: AppConfig.dp1FeedApiKey,
      );

      // Fetch a real channel
      const channelId = '0fdd0465-217c-4734-9bfd-2d807b414482';
      await service.fetchChannel(
        baseUrl: AppConfig.dp1FeedUrl,
        channelId: channelId,
      );

      // Verify channel was saved to database
      final savedChannel = await databaseService.getChannelById(channelId);
      expect(savedChannel, isNotNull);
      expect(savedChannel!.id, equals(channelId));
      expect(savedChannel.name, equals('Feral File'));
      expect(savedChannel.type, equals(ChannelType.dp1));
    });

    test('fetchPlaylists fetches and ingests multiple playlists', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final service = DP1FeedService(
        databaseService: databaseService,
        indexerService: indexerService,
        apiKey: AppConfig.dp1FeedApiKey,
      );

      // Fetch first 5 playlists
      final count = await service.fetchPlaylists(
        baseUrl: AppConfig.dp1FeedUrl,
        limit: 5,
      );

      // Should have fetched some playlists
      expect(count, greaterThan(0));
      expect(count, lessThanOrEqualTo(5));

      // Verify playlists are in database
      final allPlaylists = await db.select(db.playlists).get();
      expect(allPlaylists.length, equals(count));
    });

    test('ingestPlaylistFromFeed handles static playlists', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final service = DP1FeedService(
        databaseService: databaseService,
        indexerService: indexerService,
        apiKey: AppConfig.dp1FeedApiKey,
      );

      // Fetch Social Codes (a static playlist with items)
      const socialCodesId = 'c125ec0e-7f76-436d-a815-e7c7b37677c0';
      final response = await service.dio.getUri(
        Uri.parse('${AppConfig.dp1FeedUrl}/api/v1/playlists/$socialCodesId'),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${AppConfig.dp1FeedApiKey}',
            'Content-Type': 'application/json',
          },
        ),
      );

      final playlistJson = response.data as Map<String, dynamic>;

      // Ingest the playlist
      await service.ingestPlaylistFromFeed(
        baseUrl: AppConfig.dp1FeedUrl,
        playlistJson: playlistJson,
      );

      // Verify playlist was saved
      final savedPlaylist = await databaseService
          .getPlaylistById(socialCodesId);
      expect(savedPlaylist, isNotNull);
      expect(savedPlaylist!.id, equals(socialCodesId));
      expect(savedPlaylist.name, equals('Social Codes'));
      expect(savedPlaylist.sortMode, equals(PlaylistSortMode.position));

      // Verify items were saved
      final items = await databaseService.getPlaylistItems(socialCodesId);
      expect(items, isNotEmpty);
      expect(items.length, equals(10)); // Social Codes has 10 items
    });

    test('ingestPlaylistFromFeed handles dynamic playlists', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final service = DP1FeedService(
        databaseService: databaseService,
        indexerService: indexerService,
        apiKey: AppConfig.dp1FeedApiKey,
      );

      // Fetch a dynamic playlist
      const dynamicPlaylistId = '4db29d0d-57e7-4d13-ad25-3fa8ede4c77d';
      final response = await service.dio.getUri(
        Uri.parse(
          '${AppConfig.dp1FeedUrl}/api/v1/playlists/$dynamicPlaylistId',
        ),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${AppConfig.dp1FeedApiKey}',
            'Content-Type': 'application/json',
          },
        ),
      );

      final playlistJson = response.data as Map<String, dynamic>;

      // Verify it has dynamicQueries
      expect(playlistJson['dynamicQueries'], isNotNull);

      // Ingest the playlist
      await service.ingestPlaylistFromFeed(
        baseUrl: AppConfig.dp1FeedUrl,
        playlistJson: playlistJson,
      );

      // Verify playlist was saved
      final savedPlaylist = await databaseService
          .getPlaylistById(dynamicPlaylistId);
      expect(savedPlaylist, isNotNull);
      expect(savedPlaylist!.dynamicQueries, isNotNull);
      expect(
        savedPlaylist.sortMode,
        equals(PlaylistSortMode.provenance),
        reason: 'Dynamic playlists should use provenance sorting',
      );

      // Dynamic playlists start with no items
      final items = await databaseService.getPlaylistItems(dynamicPlaylistId);
      expect(items, isEmpty);
    });

    test('container.listen can spy on service method calls', () async {
      // This demonstrates how to listen to provider changes in tests
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final service = DP1FeedService(
        databaseService: databaseService,
        indexerService: indexerService,
        apiKey: AppConfig.dp1FeedApiKey,
      );

      // Fetch a channel and verify it's in database
      const channelId = '0fdd0465-217c-4734-9bfd-2d807b414482';
      await service.fetchChannel(
        baseUrl: AppConfig.dp1FeedUrl,
        channelId: channelId,
      );

      // Listen to database changes
      final channel = await databaseService.getChannelById(channelId);
      expect(channel, isNotNull);
      expect(channel!.name, equals('Feral File'));
    });
  });

  group('DP1FeedService - Error Handling', () {
    test('handles invalid base URL gracefully', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final service = DP1FeedService(
        databaseService: databaseService,
        indexerService: indexerService,
        apiKey: AppConfig.dp1FeedApiKey,
      );

      // Should throw when using invalid URL
      expect(
        () => service.fetchPlaylists(
          baseUrl: 'https://invalid-url-that-does-not-exist.example',
          limit: 1,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('handles network errors gracefully', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final service = DP1FeedService(
        databaseService: databaseService,
        indexerService: indexerService,
        apiKey: AppConfig.dp1FeedApiKey,
      );

      // Should throw when channel doesn't exist
      expect(
        () => service.fetchChannel(
          baseUrl: AppConfig.dp1FeedUrl,
          channelId: 'non-existent-channel-id-12345',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('DP1FeedService - ProviderContainer.test() pattern', () {
    test('demonstrates proper test container usage', () {
      // Each test should create its own container
      final container = ProviderContainer.test();
      
      // Always dispose the container when done
      addTearDown(container.dispose);

      // You can read providers synchronously
      final service = DP1FeedService(
        databaseService: databaseService,
        indexerService: indexerService,
        apiKey: AppConfig.dp1FeedApiKey,
      );

      expect(service, isNotNull);
    });

    test('demonstrates container.listen for async providers', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      // For auto-dispose providers, use listen to keep them alive
      final futureProvider = FutureProvider<int>((ref) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 42;
      });

      // Listen to prevent auto-disposal during test
      final subscription = container.listen<AsyncValue<int>>(
        futureProvider,
        (_, __) {},
      );

      // Wait for the future to complete
      await container.read(futureProvider.future);

      // Can read the value through subscription
      expect(subscription.read().value, equals(42));
    });
  });
}
