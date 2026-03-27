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

    test('saves all items as fallback when tokens is empty', () {
      final items = [
        dp1ItemWithCid('item_1', '1'),
        dp1ItemWithCid('item_2', '2'),
      ];
      final result = buildEnrichedPlaylistItemsToSave(
        missingItems: items,
        tokens: [],
      );
      // Items with no tokens are saved as fallback DP1 items
      expect(result, hasLength(2));
      expect(result[0].id, 'item_1');
      expect(result[0].thumbnailUrl, isNull); // Fallback, no token
      expect(result[1].id, 'item_2');
      expect(result[1].thumbnailUrl, isNull); // Fallback, no token
    });

    test('saves enriched items with token and fallback items without', () {
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

      // Both items are saved; item_1 enriched, item_2 as fallback
      expect(result, hasLength(2));
      final item1Result = result.firstWhere((e) => e.id == 'item_1');
      expect(item1Result.thumbnailUrl, isNotNull); // Enriched with token
      
      final item2Result = result.firstWhere((e) => e.id == 'item_2');
      expect(item2Result.thumbnailUrl, isNull); // Fallback, no token
    });

    test('saves items with no cid as fallback DP1 items', () {
      final itemNoCid = dp1ItemNoCid('item_x');
      final itemWithCid = dp1ItemWithCid('item_y', '1');
      final tokens = [tokenWithCid('eip155:1:erc721:0xabc:1')];

      final result = buildEnrichedPlaylistItemsToSave(
        missingItems: [itemNoCid, itemWithCid],
        tokens: tokens,
      );

      // Both items are saved; item_x as fallback, item_y enriched
      expect(result, hasLength(2));
      
      final itemXResult = result.firstWhere((e) => e.id == 'item_x');
      expect(itemXResult.thumbnailUrl, isNull); // Fallback, no cid
      
      final itemYResult = result.firstWhere((e) => e.id == 'item_y');
      expect(itemYResult.thumbnailUrl, isNotNull); // Enriched
    });
  });
}
