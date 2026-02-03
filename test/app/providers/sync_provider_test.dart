import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/providers/sync_provider.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class SyncFakeIndexerClient extends IndexerClient {
  SyncFakeIndexerClient({
    required this.address,
    required this.tokenCid,
    required this.token,
  }) : super(endpoint: 'http://localhost');

  final String address;
  final String tokenCid;
  final AssetToken token;

  Map<String, dynamic> _tokenToGraphQl(AssetToken t) {
    return <String, dynamic>{
      'id': t.id,
      'token_cid': t.cid,
      'chain': t.chain,
      'standard': t.standard,
      'contract_address': t.contractAddress,
      'token_number': t.tokenNumber,
      'current_owner': t.currentOwner,
      'updated_at': t.updatedAt?.toIso8601String(),
      'metadata': t.metadata?.toJson(),
      'owners': t.owners?.toJson(),
      'provenance_events': t.provenanceEvents?.toJson(),
      'enrichment_source': t.enrichmentSource?.toJson(),
      'metadata_media_assets':
          t.metadataMediaAssets?.map((e) => e.toJson()).toList(),
      'enrichment_source_media_assets':
          t.enrichmentSourceMediaAssets?.map((e) => e.toJson()).toList(),
    };
  }

  @override
  Future<Map<String, dynamic>?> query({
    required String doc,
    Map<String, dynamic> vars = const {},
    String? subKey,
  }) async {
    if (subKey == 'tokens') {
      final cids = (vars['cids'] as List?)?.whereType<String>().toList() ??
          const <String>[];
      if (cids.contains(tokenCid)) {
        return <String, dynamic>{
          'items': <Map<String, dynamic>>[
            _tokenToGraphQl(token),
          ],
          'offset': 0,
          'total': 1,
        };
      }
      return <String, dynamic>{
        'items': <Map<String, dynamic>>[],
        'offset': 0,
        'total': 0,
      };
    }

    if (subKey != 'changes') return null;

    final anchor = vars['anchor'] as int?;
    if (anchor == null) {
      // First page includes one mint and a next_anchor.
      return <String, dynamic>{
        'items': [
          {
            'id': 1,
            'subject_type': 'token',
            'subject_id': 't1',
            'changed_at': '2025-01-01T00:00:00Z',
            'meta': {
              'chain': 'eip155:1',
              'standard': 'erc721',
              'contract': '0xabc',
              'token_number': '1',
              'token_id': 123,
              'from': null,
              'to': address,
            },
            'created_at': '2025-01-01T00:00:00Z',
            'updated_at': '2025-01-01T00:00:00Z',
          }
        ],
        'offset': 0,
        'total': 1,
        'next_anchor': 42,
      };
    }

    // Second page empty -> stop.
    return <String, dynamic>{
      'items': <Map<String, dynamic>>[],
      'offset': 0,
      'total': 1,
      'next_anchor': null,
    };
  }
}

void main() {
  test('IncrementalSync ingests minted token into address playlist', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);

    const address = '0x1111111111111111111111111111111111111111';
    const chain = 'eip155:1';
    final playlistId = 'addr:$chain:${address.toUpperCase()}';

    // Seed an address playlist so incremental sync can discover it.
    await dbService.ingestPlaylist(
      Playlist(
        id: playlistId,
        name: 'test address',
        type: PlaylistType.addressBased,
        channelId: 'my_collection',
        playlistSource: PlaylistSource.personal,
        ownerAddress: address.toUpperCase(),
        ownerChain: chain,
        sortMode: PlaylistSortMode.provenance,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    const tokenCid = 'eip155:1:erc721:0xabc:1';
    final token = AssetToken(
      id: 123,
      cid: tokenCid,
      chain: chain,
      standard: 'erc721',
      contractAddress: '0xabc',
      tokenNumber: '1',
      currentOwner: address,
      owners: PaginatedOwners(
        items: [
          Owner(ownerAddress: address, quantity: '1'),
        ],
        total: 1,
        offset: 0,
      ),
    );

    final client = SyncFakeIndexerClient(
      address: address.toUpperCase(),
      tokenCid: tokenCid,
      token: token,
    );

    final indexerService = IndexerService(
      client: client,
    );

    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWithValue(dbService),
        indexerServiceProvider.overrideWithValue(indexerService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(incrementalSyncProvider.notifier);
    notifier.start(interval: const Duration(days: 1));
    await notifier.syncNow();

    final items = await dbService.getPlaylistItems(playlistId);
    expect(items, isNotEmpty);
    expect(items.first.id, equals(tokenCid));
  });
}
