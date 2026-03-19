import 'package:app/domain/extensions/playlist_item_ext.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/token_transformer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TokenTransformer', () {
    group('assetTokenToPlaylistItem', () {
      test('transforms AssetToken to PlaylistItem correctly', () {
        final token = AssetToken(
          id: 1,
          cid: 'cid_test123',
          chain: 'eip155:1',
          standard: 'ERC-721',
          contractAddress: '0xCONTRACT',
          tokenNumber: '1',
          display: TokenMetadata(
            name: 'Test Artwork',
            imageUrl: 'https://example.com/thumb.jpg',
            animationUrl: 'https://example.com/animation.mp4',
            artists: [
              Artist(did: 'did:1', name: 'Artist 1'),
              Artist(did: 'did:2', name: 'Artist 2'),
            ],
          ),
        );

        final item = TokenTransformer.assetTokenToPlaylistItem(token: token);

        expect(item.id, 'cid_test123');
        expect(item.kind, PlaylistItemKind.indexerToken);
        expect(item.title, 'Test Artwork');
        expect(item.artistName, 'Artist 1, Artist 2');
        expect(item.artists?.map((a) => a.name), ['Artist 1', 'Artist 2']);
        expect(item.source, 'https://example.com/animation.mp4');
        expect(item.thumbnailUrl, 'https://example.com/thumb.jpg');
        expect(item.provenance, isNotNull);
        expect(item.provenance!.type.toString(), contains('onChain'));
        expect(item.provenance!.contract.address, '0xCONTRACT');
        expect(item.provenance!.contract.tokenId, '1');
      });

      test('builds provenance for Tezos FA2 token', () {
        final token = AssetToken(
          id: 1,
          cid: 'tezos:mainnet:fa2:KT1ABC:42',
          chain: 'tezos:mainnet',
          standard: 'fa2',
          contractAddress: 'KT1ABC',
          tokenNumber: '42',
        );

        final item = TokenTransformer.assetTokenToPlaylistItem(token: token);

        expect(item.provenance, isNotNull);
        expect(item.provenance!.contract.chain.toString(), contains('tezos'));
        expect(item.provenance!.contract.standard.toString(), contains('fa2'));
        expect(item.provenance!.contract.address, 'KT1ABC');
        expect(item.provenance!.contract.tokenId, '42');
      });

      test('returns null provenance when address or tokenId empty', () {
        final token = AssetToken(
          id: 1,
          cid: 'bad_cid',
          chain: 'eip155:1',
          standard: 'ERC-721',
          contractAddress: '',
          tokenNumber: '1',
        );

        final item = TokenTransformer.assetTokenToPlaylistItem(token: token);

        expect(item.provenance, isNull);
      });

      test('uses display animation URL for source', () {
        final token = AssetToken(
          id: 1,
          cid: 'cid_test123',
          chain: 'eip155:1',
          standard: 'ERC-721',
          contractAddress: '0xCONTRACT',
          tokenNumber: '1',
          display: TokenMetadata(
            name: 'Display Name',
            animationUrl: 'https://example.com/display-animation.mp4',
            imageUrl: 'https://example.com/display-image.jpg',
          ),
        );

        final item = TokenTransformer.assetTokenToPlaylistItem(token: token);

        expect(item.source, 'https://example.com/display-animation.mp4');
      });

      test('handles missing title', () {
        final token = AssetToken(
          id: 1,
          cid: 'cid_test123',
          chain: 'eip155:1',
          standard: 'ERC-721',
          contractAddress: '0xCONTRACT',
          tokenNumber: '1',
        );

        final item = TokenTransformer.assetTokenToPlaylistItem(token: token);

        expect(item.title, 'Untitled');
      });

      test('computes sort key from provenance (microseconds)', () {
        final token = AssetToken(
          id: 1,
          cid: 'cid_test123',
          chain: 'eip155:1',
          standard: 'ERC-721',
          contractAddress: '0xCONTRACT',
          tokenNumber: '1',
          provenanceEvents: PaginatedProvenanceEvents(
            items: [
              ProvenanceEvent(
                chain: 'eip155:1',
                eventType: ProvenanceEventType.transfer,
                toAddress: '0xABCD',
                timestamp: DateTime.fromMicrosecondsSinceEpoch(1000000),
              ),
              ProvenanceEvent(
                chain: 'eip155:1',
                eventType: ProvenanceEventType.transfer,
                toAddress: '0xABCD',
                timestamp: DateTime.fromMicrosecondsSinceEpoch(2000000),
              ),
              ProvenanceEvent(
                chain: 'eip155:1',
                eventType: ProvenanceEventType.transfer,
                toAddress: '0xEFGH',
                timestamp: DateTime.fromMicrosecondsSinceEpoch(3000000),
              ),
            ],
            total: 3,
            offset: 0,
          ),
        );

        final item = TokenTransformer.assetTokenToPlaylistItem(
          token: token,
          ownerAddress: '0xABCD',
        );

        // Should use the latest timestamp where toAddress matches owner.
        expect(item.sortKeyUs, 2000000);
      });

      test('returns 0 sort key when no matching provenance', () {
        final token = AssetToken(
          id: 1,
          cid: 'cid_test123',
          chain: 'eip155:1',
          standard: 'ERC-721',
          contractAddress: '0xCONTRACT',
          tokenNumber: '1',
          provenanceEvents: PaginatedProvenanceEvents(
            items: [
              ProvenanceEvent(
                chain: 'eip155:1',
                eventType: ProvenanceEventType.transfer,
                toAddress: '0xEFGH',
                timestamp: DateTime.fromMicrosecondsSinceEpoch(1000000),
              ),
            ],
            total: 1,
            offset: 0,
          ),
        );

        final item = TokenTransformer.assetTokenToPlaylistItem(
          token: token,
          ownerAddress: '0xABCD',
        );

        expect(item.sortKeyUs, 0);
      });
    });

    group('filterTokensByOwner', () {
      test('filters tokens by owner address', () {
        final tokens = [
          AssetToken(
            id: 1,
            cid: 'token1',
            chain: 'eip155:1',
            standard: 'ERC-721',
            contractAddress: '0xCONTRACT',
            tokenNumber: '1',
            owners: PaginatedOwners(
              items: [Owner(ownerAddress: '0xABCD', quantity: '1')],
              total: 1,
              offset: 0,
            ),
          ),
          AssetToken(
            id: 2,
            cid: 'token2',
            chain: 'eip155:1',
            standard: 'ERC-721',
            contractAddress: '0xCONTRACT',
            tokenNumber: '2',
            owners: PaginatedOwners(
              items: [Owner(ownerAddress: '0xEFGH', quantity: '1')],
              total: 1,
              offset: 0,
            ),
          ),
          AssetToken(
            id: 3,
            cid: 'token3',
            chain: 'eip155:1',
            standard: 'ERC-721',
            contractAddress: '0xCONTRACT',
            tokenNumber: '3',
            owners: PaginatedOwners(
              items: [Owner(ownerAddress: '0xABCD', quantity: '1')],
              total: 1,
              offset: 0,
            ),
          ),
        ];

        final filtered = TokenTransformer.filterTokensByOwner(
          tokens: tokens,
          ownerAddress: '0xabcd', // Case insensitive
        );

        expect(filtered.length, 2);
        expect(filtered[0].cid, 'token1');
        expect(filtered[1].cid, 'token3');
      });

      test('falls back to currentOwner field', () {
        final tokens = [
          AssetToken(
            id: 1,
            cid: 'token1',
            chain: 'eip155:1',
            standard: 'ERC-721',
            contractAddress: '0xCONTRACT',
            tokenNumber: '1',
            currentOwner: '0xABCD',
            owners: PaginatedOwners(items: const [], total: 0, offset: 0),
          ),
          AssetToken(
            id: 2,
            cid: 'token2',
            chain: 'eip155:1',
            standard: 'ERC-721',
            contractAddress: '0xCONTRACT',
            tokenNumber: '2',
            currentOwner: '0xEFGH',
            owners: PaginatedOwners(items: const [], total: 0, offset: 0),
          ),
        ];

        final filtered = TokenTransformer.filterTokensByOwner(
          tokens: tokens,
          ownerAddress: '0xabcd',
        );

        expect(filtered.length, 1);
        expect(filtered[0].cid, 'token1');
      });
    });

    group('generateItemId', () {
      test('generates ID with owner address', () {
        final id = TokenTransformer.generateItemId(
          tokenId: 'cid_test',
          ownerAddress: '0xABCD',
        );

        expect(id, 'cid_test_0xabcd');
      });

      test('returns token ID when no owner', () {
        final id = TokenTransformer.generateItemId(
          tokenId: 'cid_test',
        );

        expect(id, 'cid_test');
      });
    });
  });
}
