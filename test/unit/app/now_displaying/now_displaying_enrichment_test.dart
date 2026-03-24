import 'package:app/app/now_displaying/now_displaying_enrichment.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/dp1/dp1_provenance.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildEnrichedPlaylistItemsToSave', () {
    /// DP1 item with cid = 'eip155:1:erc721:0xabc:1'
    DP1PlaylistItem dp1ItemWithCid(String id, String cidSuffix) {
      return DP1PlaylistItem(
        id: id,
        duration: 60,
        title: 'Item $id',
        provenance: DP1Provenance(
          type: DP1ProvenanceType.onChain,
          contract: DP1Contract(
            chain: DP1ProvenanceChain.evm,
            standard: DP1ProvenanceStandard.erc721,
            address: '0xabc',
            tokenId: cidSuffix,
          ),
        ),
      );
    }

    /// DP1 item without provenance (no cid)
    DP1PlaylistItem dp1ItemNoCid(String id) {
      return DP1PlaylistItem(
        id: id,
        duration: 60,
        title: 'Item $id',
      );
    }

    AssetToken tokenWithCid(String cid) {
      return AssetToken(
        id: 1,
        cid: cid,
        chain: 'eip155:1',
        standard: 'ERC-721',
        contractAddress: '0xabc',
        tokenNumber: '1',
        display: TokenMetadata(
          name: 'Token $cid',
          imageUrl: 'https://example.com/$cid.jpg',
        ),
      );
    }

    test('returns empty when missingItems is empty', () {
      final tokens = [tokenWithCid('eip155:1:erc721:0xabc:1')];
      final result = buildEnrichedPlaylistItemsToSave(
        missingItems: [],
        tokens: tokens,
      );
      expect(result, isEmpty);
    });

    test('saves all items even when tokens is empty (fallback to DP1 data)', () {
      final items = [
        dp1ItemWithCid('item_1', '1'),
        dp1ItemWithCid('item_2', '2'),
      ];
      final result = buildEnrichedPlaylistItemsToSave(
        missingItems: items,
        tokens: [],
      );
      // All items should be saved as DP1 fallback (no enrichment)
      expect(result.length, 2);
      expect(result.map((p) => p.id).toSet(), {'item_1', 'item_2'});
      // Without token, thumbnailUrl should be null
      expect(result.every((p) => p.thumbnailUrl == null), true);
    });

    test('saves items with matching token (enriched)', () {
      // Item with cid eip155:1:erc721:0xabc:1
      final item1 = dp1ItemWithCid('item_1', '1');
      // Item with cid eip155:1:erc721:0xabc:2
      final item2 = dp1ItemWithCid('item_2', '2');

      final tokens = [
        tokenWithCid('eip155:1:erc721:0xabc:1'),
        // No token for item_2's cid
      ];

      final result = buildEnrichedPlaylistItemsToSave(
        missingItems: [item1, item2],
        tokens: tokens,
      );

      // Both items should be saved, but only item_1 is enriched
      expect(result.length, 2);
      final item1Result = result.singleWhere((p) => p.id == 'item_1');
      final item2Result = result.singleWhere((p) => p.id == 'item_2');
      
      expect(item1Result.thumbnailUrl, isNotNull); // Enriched with token
      expect(item2Result.thumbnailUrl, isNull);    // Fallback to DP1 data
    });

    test('includes items with no cid (fallback to DP1 data)', () {
      final itemNoCid = dp1ItemNoCid('item_x');
      final tokens = [tokenWithCid('eip155:1:erc721:0xabc:1')];

      final result = buildEnrichedPlaylistItemsToSave(
        missingItems: [itemNoCid],
        tokens: tokens,
      );

      // Item without cid should still be saved as DP1 fallback
      expect(result.length, 1);
      expect(result.single.id, 'item_x');
      expect(result.single.thumbnailUrl, isNull);
    });
  });
}
