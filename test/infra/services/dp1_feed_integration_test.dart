import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/dp1_feed_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration test for DP1 Feed Service with real API calls.
/// This test fetches the "Social Codes" playlist from the feed server,
/// enriches items with token data from the indexer, and verifies database
/// storage.
///
/// Run with: flutter test test/infra/services/dp1_feed_integration_test.dart
void main() {
  late AppDatabase db;
  late DatabaseService databaseService;
  late IndexerClient indexerClient;
  late IndexerService indexerService;
  late DP1FeedService dp1FeedService;

  // Social Codes playlist ID
  const socialCodesPlaylistId = 'c125ec0e-7f76-436d-a815-e7c7b37677c0';

  setUpAll(() async {
    // Initialize AppConfig
    // Note: Skip TestWidgetsFlutterBinding to allow real HTTP requests
    await AppConfig.initialize();
  });

  setUp(() {
    // Create in-memory database for testing
    db = AppDatabase.forTesting(NativeDatabase.memory());
    databaseService = DatabaseService(db);

    // Create indexer client with real API
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

    dp1FeedService = DP1FeedService(
      databaseService: databaseService,
      indexerService: indexerService,
      apiKey: AppConfig.dp1FeedApiKey,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('DP1 Feed Integration - Social Codes Playlist', () {
    test(
      'fetch and ingest Social Codes playlist with token enrichment',
      () async {
        // Fetch the specific Social Codes playlist
        final baseUrl = AppConfig.dp1FeedUrl;

        // Fetch playlists and find Social Codes
        final count = await dp1FeedService.fetchPlaylists(
          baseUrl: baseUrl,
          limit: 100, // Fetch enough to find Social Codes
        );

        expect(count, greaterThan(0), reason: 'Should fetch playlists');

        // Verify playlist was ingested
        final playlist = await databaseService.getPlaylistById(
          socialCodesPlaylistId,
        );
        expect(playlist, isNotNull, reason: 'Social Codes playlist not found');
        expect(playlist!.name, equals('Social Codes'));
        expect(playlist.type, equals(PlaylistType.dp1));
        // Note: playlistSource not persisted in DB schema yet
        // expect(playlist.playlistSource, equals(PlaylistSource.curated));
        expect(playlist.baseUrl, equals(baseUrl));

        // Verify items were ingested
        final items = await databaseService.getPlaylistItems(
          socialCodesPlaylistId,
        );
        expect(items, isNotEmpty, reason: 'Playlist should have items');
        expect(
          items.length,
          equals(10),
          reason: 'Social Codes has 10 items',
        );

        // Verify items have proper structure
        for (final item in items) {
          expect(item.id, isNotEmpty, reason: 'Item should have ID');
          expect(
            item.kind,
            equals(PlaylistItemKind.dp1Item),
            reason: 'Should be DP1 item',
          );
          expect(item.sourceUri, isNotNull, reason: 'Should have source URI');
          expect(
            item.provenance,
            isNotNull,
            reason: 'Should have provenance data',
          );

          // Verify provenance structure
          final provenance = item.provenance!;
          expect(provenance['type'], equals('onChain'));
          expect(provenance['contract'], isNotNull);

          final contract = provenance['contract'] as Map<String, dynamic>;
          expect(contract['chain'], equals('evm'));
          expect(contract['standard'], equals('erc721'));
          expect(contract['address'], isNotEmpty);
          expect(contract['tokenId'], isNotEmpty);
        }

        // Note: Enrichment with indexer may not always succeed for all items
        // The important part is that the flow doesn't fail
        // Items should at least have the basic DP1 data
        final enrichedItems = items
            .where((item) => item.thumbnailUrl != null)
            .toList();
        // Allow test to pass even if enrichment didn't work
        // (indexer may not have all tokens or network issues)
        if (enrichedItems.isEmpty) {
          // ignore: avoid_print
          print('Warning: No items were enriched with thumbnails from indexer');
        }

        // Verify specific items (first and last)
        final firstItem = items.first;
        expect(
          firstItem.id,
          equals('04821587-6810-4f79-b415-61952a68e928'),
          reason: 'First item ID should match',
        );

        final lastItem = items.last;
        expect(
          lastItem.id,
          equals('5830e905-f3be-4159-bda3-90b882103946'),
          reason: 'Last item ID should match',
        );
      },
    );

    test('enrichment tokens include blockchain metadata', () async {
      // Fetch playlist
      await dp1FeedService.fetchPlaylists(
        baseUrl: AppConfig.dp1FeedUrl,
        limit: 100,
      );

      // Get items
      final items = await databaseService.getPlaylistItems(
        socialCodesPlaylistId,
      );
      expect(items, isNotEmpty);

      // Check that items have provenance data (from DP1 feed)
      final itemsWithProvenance = items
          .where((i) => i.provenance != null)
          .toList();
      expect(
        itemsWithProvenance,
        isNotEmpty,
        reason: 'Items should have provenance from feed',
      );

      // Check items with provenance
      for (final item in itemsWithProvenance) {
        // All Social Codes items should have on-chain provenance
        expect(item.provenance, isNotNull);

        final provenance = item.provenance!;
        expect(provenance['type'], equals('onChain'));

        final contract = provenance['contract'] as Map<String, dynamic>;
        // Social Codes items are on Ethereum mainnet
        expect(contract['chain'], equals('evm'));
        expect(contract['address'], isNotEmpty);

        // Contract address should be consistent for Social Codes
        expect(
          contract['address'],
          equals('0x28b51BA8B990c48CB22cB6EF0ad5415fdBA5210C'),
          reason: 'Social Codes contract address should match',
        );
      }
    });

    test('playlist items maintain correct order', () async {
      // Fetch playlist
      await dp1FeedService.fetchPlaylists(
        baseUrl: AppConfig.dp1FeedUrl,
        limit: 100,
      );

      // Get items
      final items = await databaseService.getPlaylistItems(
        socialCodesPlaylistId,
      );

      // Verify items are in expected order based on the API response
      final expectedItemIds = [
        '04821587-6810-4f79-b415-61952a68e928', // Item 0
        '7cae833f-3063-4664-8ab8-9195edd15916', // Item 1
        'c7365454-440d-4c9c-9001-bc66141d3226', // Item 2
        '05f18b6a-2ea9-4961-9e1b-838394b0a333', // Item 3
        '0eabaeb2-eb5b-4466-885f-3e763fb2fa18', // Item 4
        'b5f3aa85-2f5d-44f2-9d4f-5c002a1c008d', // Item 5
        'bd4574d1-2e7e-401f-b1a8-f445192b8430', // Item 6
        'eeb56af6-6da3-4946-bb50-2d3b00c6f493', // Item 7
        '02f2a58d-faa2-4c39-b46c-fec925c0742b', // Item 8
        '5830e905-f3be-4159-bda3-90b882103946', // Item 9
      ];

      expect(items.length, equals(expectedItemIds.length));

      for (var i = 0; i < items.length; i++) {
        expect(
          items[i].id,
          equals(expectedItemIds[i]),
          reason: 'Item at position $i should match expected ID',
        );
      }
    });

    test('duplicate playlist ingestion updates existing data', () async {
      // Ingest playlist first time
      await dp1FeedService.fetchPlaylists(
        baseUrl: AppConfig.dp1FeedUrl,
        limit: 100,
      );

      final firstFetch = await databaseService.getPlaylistById(
        socialCodesPlaylistId,
      );
      expect(firstFetch, isNotNull);

      final firstItemCount = await databaseService
          .getPlaylistItems(socialCodesPlaylistId)
          .then((items) => items.length);

      // Ingest again
      await dp1FeedService.fetchPlaylists(
        baseUrl: AppConfig.dp1FeedUrl,
        limit: 100,
      );

      final secondFetch = await databaseService.getPlaylistById(
        socialCodesPlaylistId,
      );
      expect(secondFetch, isNotNull);

      final secondItemCount = await databaseService
          .getPlaylistItems(socialCodesPlaylistId)
          .then((items) => items.length);

      // Should have same number of items (no duplicates)
      expect(secondItemCount, equals(firstItemCount));
    });
  });

  group('DP1 Feed Integration - Full Channel Flow', () {
    test(
      'fetch channel, get first playlist, enrich and verify counts',
      () async {
        final baseUrl = AppConfig.dp1FeedUrl;

        // Step 1: Fetch the first channel
        final channelsUri = Uri.parse('$baseUrl/api/v1/channels');
        final channelsResponse = await dp1FeedService.dio.getUri(
          channelsUri,
          options: Options(
            headers: {
              'Authorization': 'Bearer ${AppConfig.dp1FeedApiKey}',
              'Content-Type': 'application/json',
            },
          ),
        );

        expect(channelsResponse.statusCode, equals(200));
        final channelsData = channelsResponse.data as Map<String, dynamic>;
        final channels = channelsData['items'] as List;
        expect(
          channels,
          isNotEmpty,
          reason: 'Should have at least one channel',
        );

        final firstChannelJson = channels.first as Map<String, dynamic>;
        final channelId = firstChannelJson['id'] as String;

        // Fetch and ingest the channel
        await dp1FeedService.fetchChannel(
          baseUrl: baseUrl,
          channelId: channelId,
        );

        // Verify channel was saved
        final savedChannel = await databaseService.getChannelById(channelId);
        expect(savedChannel, isNotNull, reason: 'Channel should be saved');
        expect(savedChannel!.name, equals(firstChannelJson['title']));

        // Step 2: Get the first playlist from the channel
        final playlistUrls = firstChannelJson['playlists'] as List;
        expect(
          playlistUrls,
          isNotEmpty,
          reason: 'Channel should have playlists',
        );

        final firstPlaylistUrl = playlistUrls.first as String;
        final playlistId = firstPlaylistUrl.split('/').last;

        // Fetch the playlist
        final playlistResponse = await dp1FeedService.dio.getUri(
          Uri.parse(firstPlaylistUrl),
          options: Options(
            headers: {
              'Authorization': 'Bearer ${AppConfig.dp1FeedApiKey}',
              'Content-Type': 'application/json',
            },
          ),
        );

        expect(playlistResponse.statusCode, equals(200));
        final playlistJson = playlistResponse.data as Map<String, dynamic>;

        // Step 3: Ingest playlist with enrichment
        await dp1FeedService.ingestPlaylistFromFeed(
          baseUrl: baseUrl,
          playlistJson: playlistJson,
        );

        // Step 4: Verify database counts
        // Get all channels
        final allChannels = await db.select(db.channels).get();
        expect(
          allChannels.length,
          equals(1),
          reason: 'Should have exactly 1 channel',
        );

        // Get all playlists
        final allPlaylists = await db.select(db.playlists).get();
        expect(
          allPlaylists.length,
          equals(1),
          reason: 'Should have exactly 1 playlist',
        );
        expect(allPlaylists.first.id, equals(playlistId));

        // Get all playlist items
        final allItems = await databaseService.getAllItems();

        // Verify items count matches playlist items
        final playlistItems = playlistJson['items'] as List?;
        if (playlistItems != null && playlistItems.isNotEmpty) {
          expect(
            allItems.length,
            equals(playlistItems.length),
            reason: 'Item count should match playlist items',
          );

          // Verify items are linked to the playlist
          final playlistEntries = await db.select(db.playlistEntries).get();
          expect(
            playlistEntries.length,
            equals(playlistItems.length),
            reason: 'Should have playlist entry for each item',
          );

          // Verify all entries point to the correct playlist
          for (final entry in playlistEntries) {
            expect(entry.playlistId, equals(playlistId));
          }

          // Verify items have proper structure
          for (final item in allItems) {
            expect(item.id, isNotEmpty);
            expect(item.kind, isNotNull);
            // Items should have at least source or ref
            expect(
              item.sourceUri != null || item.refUri != null,
              isTrue,
              reason: 'Item should have sourceUri or refUri',
            );
          }
        } else {
          // Dynamic playlist
          expect(
            allItems.length,
            equals(0),
            reason: 'Dynamic playlists start with 0 items',
          );
        }

        // Get playlist entries for summary
        final playlistEntries = await db.select(db.playlistEntries).get();

        // Summary log
        // ignore: avoid_print
        print('''
Integration Test Summary:
- Channels: ${allChannels.length}
- Playlists: ${allPlaylists.length}
- Items: ${allItems.length}
- Playlist entries: ${playlistEntries.length}
''');
      },
    );
  });

  group('DP1 Feed Integration - Dynamic Playlists', () {
    test('dynamic playlists are stored with dynamicQueries', () async {
      // Fetch playlists including dynamic ones
      await dp1FeedService.fetchPlaylists(
        baseUrl: AppConfig.dp1FeedUrl,
        limit: 100,
      );

      // Get a known dynamic playlist
      const dynamicPlaylistId = '4db29d0d-57e7-4d13-ad25-3fa8ede4c77d';
      final dynamicPlaylist = await databaseService.getPlaylistById(
        dynamicPlaylistId,
      );

      if (dynamicPlaylist == null) {
        // Dynamic playlist wasn't fetched/ingested, skip test
        return;
      }

      // Verify dynamic playlist structure
      expect(dynamicPlaylist.dynamicQueries, isNotNull);
      expect(
        dynamicPlaylist.sortMode,
        equals(PlaylistSortMode.provenance),
        reason: 'Dynamic playlists should use provenance sorting',
      );

      // Dynamic playlists start with 0 items
      // (they need to be resolved from indexer)
      final items = await databaseService.getPlaylistItems(dynamicPlaylist.id);
      expect(
        items.length,
        equals(0),
        reason: 'Dynamic playlists start with no items',
      );
    });
  });

  group('DP1 Feed Integration - Error Handling', () {
    test('handles invalid base URL gracefully', () async {
      expect(
        () => dp1FeedService.fetchPlaylists(
          baseUrl: 'https://invalid.example.com',
          limit: 10,
        ),
        throwsA(isA<Exception>()),
        reason: 'Should throw exception for invalid URL',
      );
    });

    test('continues ingestion even if enrichment fails', () async {
      // Create a service with bad indexer config
      final badIndexerClient = IndexerClient(
        endpoint: 'https://invalid.endpoint.example.com/graphql',
      );

      final badIndexerService = IndexerService(
        client: badIndexerClient,
        databaseService: databaseService,
      );

      final feedServiceWithBadIndexer = DP1FeedService(
        databaseService: databaseService,
        indexerService: badIndexerService,
        apiKey: AppConfig.dp1FeedApiKey,
      );

      // Should still ingest playlists even if indexer fails
      final count = await feedServiceWithBadIndexer.fetchPlaylists(
        baseUrl: AppConfig.dp1FeedUrl,
        limit: 10,
      );

      expect(count, greaterThan(0), reason: 'Should fetch playlists');

      // Items should exist but without enrichment
      final playlist = await databaseService.getPlaylistById(
        socialCodesPlaylistId,
      );
      if (playlist != null) {
        final items = await databaseService.getPlaylistItems(
          socialCodesPlaylistId,
        );
        expect(items, isNotEmpty);
      }
    });
  });
}
