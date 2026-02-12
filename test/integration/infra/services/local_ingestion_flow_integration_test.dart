import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/dp1_playlist_items_enrichment_service.dart';
import 'package:app/infra/services/indexer_service.dart';
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

  // Integration test: validates non-UI ingestion + enrichment flow
  // against real SQLite using deterministic test data.
  test(
    'ingests bare DP1 data then enriches all rows into ready-to-show items',
    () async {
      final channel = DP1Channel(
        id: 'ch-local',
        slug: 'local-channel',
        title: 'Local Channel',
        playlists: const <String>[],
        created: DateTime.parse('2025-01-01T00:00:00Z'),
      );

      final playlist = DP1Playlist(
        dpVersion: '1.0.0',
        id: 'pl-local',
        slug: 'local-playlist',
        title: 'Local Playlist',
        created: DateTime.parse('2025-01-01T00:00:00Z'),
        signature: 'sig',
        items: <DP1PlaylistItem>[
          DP1PlaylistItem.fromJson(
            {
              'id': 'item-1',
              'duration': 0,
              'provenance': {
                'type': 'onChain',
                'contract': {
                  'chain': 'evm',
                  'standard': 'erc721',
                  'address': '0xabc',
                  'tokenId': '1',
                },
              },
            },
          ),
          DP1PlaylistItem.fromJson(
            {
              'id': 'item-2',
              'duration': 0,
              'provenance': {
                'type': 'onChain',
                'contract': {
                  'chain': 'evm',
                  'standard': 'erc721',
                  'address': '0xabc',
                  'tokenId': '2',
                },
              },
            },
          ),
        ],
      );

      await context.databaseService.ingestPublisher(id: 9, name: 'Feral File');
      await context.databaseService.ingestDP1ChannelWithPlaylistsBare(
        baseUrl: 'https://feed.local',
        channel: channel,
        playlists: <DP1Playlist>[playlist],
        publisherId: 9,
      );

      final enrichmentService = DP1PlaylistItemsEnrichmentService(
        indexerService: _DeterministicIndexerService(),
        databaseService: context.databaseService,
      );

      final completed = await enrichmentService.processAll();
      expect(completed, isTrue);

      final playlists = await context.databaseService.getPlaylistsByChannel(
        channel.id,
      );
      expect(playlists, hasLength(1));
      expect(playlists.first.itemCount, equals(2));

      final items = await context.databaseService.getPlaylistItems(playlist.id);
      expect(items, hasLength(2));
      expect(items.every((item) => item.thumbnailUrl != null), isTrue);

      final remainingBare = await context.databaseService
          .loadHighPriorityBareItems(
            maxPerPlaylist: 8,
            maxTotal: 100,
          );
      expect(remainingBare, isEmpty);
    },
  );
}

class _DeterministicIndexerService extends IndexerService {
  _DeterministicIndexerService()
    : super(client: IndexerClient(endpoint: 'http://localhost'));

  @override
  Future<List<AssetToken>> fetchTokensByCIDs({
    required List<String> tokenCids,
  }) async {
    return tokenCids
        .map(
          (cid) => AssetToken(
            id: cid.hashCode,
            cid: cid,
            chain: 'eip155:1',
            standard: 'erc721',
            contractAddress: '0xabc',
            tokenNumber: '1',
            metadata: TokenMetadata(
              name: 'Work $cid',
              imageUrl: 'https://images.example/$cid.png',
            ),
          ),
        )
        .toList(growable: false);
  }
}
