import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/infra/api/dp1_feed_api.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/dp1_playlist_items_enrichment_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/integration_test_harness.dart';

void main() {
  late IntegrationTestContext context;

  setUpAll(() async {
    context = await createIntegrationTestContext();
  });

  tearDownAll(() async {
    await context.dispose();
  });

  // Integration test: provisions .env + real SQLite, ingests channel feed,
  // enriches items, and validates DB-ready state.
  test(
    'indexes channel 0fdd0465-217c-4734-9bfd-2d807b414482 '
    'end-to-end with enrichment',
    () async {
      const channelUrl =
          'https://dp1-feed-operator-api-prod.autonomy-system.workers.dev/api/v1/channels/0fdd0465-217c-4734-9bfd-2d807b414482';
      const publisherId = 1;
      const publisherName = 'Feral File';

      expect(
        context.provisionedEnvFile.existsSync(),
        isTrue,
        reason: 'Integration flow must run with a provisioned .env file.',
      );
      expect(
        AppConfig.indexerApiUrl,
        isNotEmpty,
        reason: 'INDEXER_API_URL is required for token enrichment integration.',
      );

      final channelUri = Uri.parse(channelUrl);
      final channelId = channelUri.pathSegments.last;
      final baseUrl = '${channelUri.scheme}://${channelUri.host}';

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      final dp1Api = Dp1FeedApiImpl(
        dio: dio,
        baseUrl: baseUrl,
        apiKey: AppConfig.dp1FeedApiKey,
      );

      final channel = await dp1Api.getChannelById(channelId);

      final playlists = await _fetchAllPlaylistsForChannel(
        api: dp1Api,
        channelId: channelId,
      );

      expect(channel.id, equals(channelId));
      expect(playlists, isNotEmpty);

      await context.databaseService.ingestPublisher(
        id: publisherId,
        name: publisherName,
      );

      await context.databaseService.ingestDP1ChannelWithPlaylistsBare(
        baseUrl: baseUrl,
        channel: channel,
        playlists: playlists,
        publisherId: publisherId,
      );

      await context.databaseService.checkpoint();

      expect(
        context.databaseFile.existsSync(),
        isTrue,
        reason:
            'Integration flow must persist to a real on-disk '
            'sqlite database file.',
      );

      final indexerService = IndexerService(
        client: IndexerClient(
          endpoint: AppConfig.indexerApiUrl,
          defaultHeaders: <String, String>{
            'Content-Type': 'application/json',
            if (AppConfig.indexerApiKey.isNotEmpty)
              'Authorization': 'ApiKey ${AppConfig.indexerApiKey}',
          },
        ),
      );

      final enrichmentService = DP1PlaylistItemsEnrichmentService(
        indexerService: indexerService,
        databaseService: context.databaseService,
      );

      final enrichmentCompleted = await enrichmentService.processAll();
      expect(enrichmentCompleted, isTrue);

      final channelRows = await context.databaseService.getChannels();
      final indexedChannel = channelRows.firstWhere(
        (row) => row.id == channelId,
      );
      expect(indexedChannel.publisherId, equals(publisherId));

      final channelPlaylists = await context.databaseService
          .getPlaylistsByChannel(
            channelId,
          );
      expect(channelPlaylists, isNotEmpty);
      expect(
        channelPlaylists.every((playlist) => playlist.itemCount > 0),
        isTrue,
        reason: 'No playlist in the indexed channel should have 0 items.',
      );

      for (final playlist in channelPlaylists) {
        final items = await context.databaseService.getPlaylistItems(
          playlist.id,
        );
        expect(
          items,
          isNotEmpty,
          reason: 'Each playlist should have queryable items after ingestion.',
        );
      }

      final unenrichedCountResult = await context.database
          .customSelect(
            '''
        SELECT COUNT(*) AS count
        FROM items i
        JOIN playlist_entries pe ON pe.item_id = i.id
        JOIN playlists p ON p.id = pe.playlist_id
        WHERE p.channel_id = ?1
          AND i.thumbnail_uri IS NULL
          AND i.list_artist_json IS NULL
        ''',
            variables: <Variable<Object>>[
              Variable.withString(channelId),
            ],
          )
          .getSingle();
      final unenrichedCount = unenrichedCountResult.read<int>('count');
      expect(
        unenrichedCount,
        equals(0),
        reason: 'All indexed items should be enriched for presentation.',
      );

      final publisherResult = await context.database
          .customSelect(
            '''
        SELECT pub.title AS publisher_title
        FROM channels ch
        JOIN publishers pub ON pub.id = ch.publisher_id
        WHERE ch.id = ?1
        ''',
            variables: <Variable<Object>>[
              Variable.withString(channelId),
            ],
          )
          .getSingle();
      expect(
        publisherResult.read<String>('publisher_title'),
        equals(publisherName),
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

Future<List<DP1Playlist>> _fetchAllPlaylistsForChannel({
  required Dp1FeedApiImpl api,
  required String channelId,
}) async {
  final playlists = <DP1Playlist>[];
  var cursor = null as String?;
  var hasMore = true;

  while (hasMore) {
    final response = await api.getPlaylists(
      channelId: channelId,
      cursor: cursor,
      limit: 50,
    );
    playlists.addAll(response.items);
    hasMore = response.hasMore;
    cursor = response.cursor;
  }

  return playlists;
}
