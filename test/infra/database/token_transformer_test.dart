import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/token_transformer.dart';

void main() {
  group('TokenTransformer', () {
    group('tokenToPlaylistItem', () {
      test('transforms token JSON to PlaylistItem correctly', () {
        final tokenJson = {
          'id': 'cid_test123',
          'title': 'Test Artwork',
          'thumbnailUrl': 'https://example.com/thumb.jpg',
          'metadata': {
            'artists': [
              {'name': 'Artist 1'},
              {'name': 'Artist 2'},
            ],
            'duration': 120,
          },
          'provenance': [],
        };

        final item = TokenTransformer.tokenToPlaylistItem(tokenJson: tokenJson);

        expect(item.id, 'cid_test123');
        expect(item.kind, PlaylistItemKind.indexerToken);
        expect(item.title, 'Test Artwork');
        expect(item.subtitle, 'Artist 1, Artist 2');
        expect(item.thumbnailUrl, 'https://example.com/thumb.jpg');
        expect(item.durationSec, 120);
        expect(item.tokenData, isNotNull);
      });

      test('handles missing title', () {
        final tokenJson = {
          'id': 'cid_test123',
        };

        final item = TokenTransformer.tokenToPlaylistItem(tokenJson: tokenJson);

        expect(item.title, 'Untitled');
      });

      test('computes sort key from provenance', () {
        final tokenJson = {
          'id': 'cid_test123',
          'title': 'Test',
          'provenance': [
            {
              'toAddress': '0xABCD',
              'timestamp': 1000000,
            },
            {
              'toAddress': '0xABCD',
              'timestamp': 2000000,
            },
            {
              'toAddress': '0xEFGH',
              'timestamp': 3000000,
            },
          ],
        };

        final item = TokenTransformer.tokenToPlaylistItem(
          tokenJson: tokenJson,
          ownerAddress: '0xABCD',
        );

        // Should use the latest timestamp where toAddress matches owner
        expect(item.provenance?['sortKeyUs'], 2000000);
      });

      test('returns 0 sort key when no matching provenance', () {
        final tokenJson = {
          'id': 'cid_test123',
          'title': 'Test',
          'provenance': [
            {
              'toAddress': '0xEFGH',
              'timestamp': 1000000,
            },
          ],
        };

        final item = TokenTransformer.tokenToPlaylistItem(
          tokenJson: tokenJson,
          ownerAddress: '0xABCD',
        );

        expect(item.provenance?['sortKeyUs'], 0);
      });
    });

    group('filterTokensByOwner', () {
      test('filters tokens by owner address', () {
        final tokens = [
          {
            'id': 'token1',
            'owners': [
              {'address': '0xABCD'},
            ],
          },
          {
            'id': 'token2',
            'owners': [
              {'address': '0xEFGH'},
            ],
          },
          {
            'id': 'token3',
            'owners': [
              {'address': '0xABCD'},
            ],
          },
        ];

        final filtered = TokenTransformer.filterTokensByOwner(
          tokens: tokens,
          ownerAddress: '0xabcd', // Case insensitive
        );

        expect(filtered.length, 2);
        expect(filtered[0]['id'], 'token1');
        expect(filtered[1]['id'], 'token3');
      });

      test('falls back to currentOwner field', () {
        final tokens = [
          {
            'id': 'token1',
            'owners': [],
            'currentOwner': '0xABCD',
          },
          {
            'id': 'token2',
            'owners': [],
            'currentOwner': '0xEFGH',
          },
        ];

        final filtered = TokenTransformer.filterTokensByOwner(
          tokens: tokens,
          ownerAddress: '0xabcd',
        );

        expect(filtered.length, 1);
        expect(filtered[0]['id'], 'token1');
      });
    });

    group('generateItemId', () {
      test('generates ID with owner address', () {
        final id = TokenTransformer.generateItemId(
          tokenId: 'cid_test',
          ownerAddress: '0xABCD',
        );

        expect(id, 'cid_test_0XABCD');
      });

      test('returns token ID when no owner', () {
        final id = TokenTransformer.generateItemId(
          tokenId: 'cid_test',
        );

        expect(id, 'cid_test');
      });
    });

    group('reconstructPlaylistItemFromTokenData', () {
      test('reconstructs playlist item from valid token data', () {
        final tokenData = {
          'id': 'cid_test123',
          'title': 'Test Artwork',
        };

        final item = TokenTransformer.reconstructPlaylistItemFromTokenData(
          tokenData,
        );

        expect(item, isNotNull);
        expect(item!.id, 'cid_test123');
        expect(item.title, 'Test Artwork');
      });

      test('returns null for invalid token data', () {
        final tokenData = <String, dynamic>{};

        final item = TokenTransformer.reconstructPlaylistItemFromTokenData(
          tokenData,
        );

        expect(item, isNull);
      });
    });
  });
}
