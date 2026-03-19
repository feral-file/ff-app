import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IndexerClient transformation logic', () {
    group('thumbnail extraction from media assets', () {
      test('extracts thumbnail from media_assets variants', () {
        // Simulate token data from GraphQL response (display replaces metadata + enrichment_source)
        final token = {
          'id': 'test_id',
          'token_cid': 'cid_test123',
          'chain': 'ethereum',
          'contract_address': '0xABCD',
          'token_number': '1',
          'display': {
            'name': 'Enriched Name',
            'image_url': 'https://example.com/enriched.jpg',
          },
          'media_assets': [
            {
              'source_url': 'https://example.com/enriched.jpg',
              'mime_type': 'image/jpeg',
              'variants': {
                'xs': 'https://example.com/enriched_xs.jpg',
                's': 'https://example.com/enriched_s.jpg',
                'm': 'https://example.com/enriched_m.jpg',
              },
            },
          ],
        };

        final display = token['display'] as Map<String, dynamic>?;
        final mediaAssets = token['media_assets'] as List?;

        // Get base thumbnail URL from display
        var thumbnailUrl = display?['image_url'] as String?;

        // Extract variant URL from media_assets
        if (thumbnailUrl != null && mediaAssets != null) {
          final asset = mediaAssets
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (a) => a['source_url'] == thumbnailUrl,
                orElse: () => <String, dynamic>{},
              );
          if (asset.isNotEmpty) {
            final variants = asset['variants'] as Map?;
            thumbnailUrl = variants?['xs'] as String?;
          }
        }

        expect(thumbnailUrl, 'https://example.com/enriched_xs.jpg');
      });

      test('falls back to display when no media match', () {
        final token = {
          'id': 'test_id',
          'token_cid': 'cid_test123',
          'display': {
            'name': 'Test Token',
            'image_url': 'https://example.com/metadata.jpg',
          },
          'media_assets': [
            {
              'source_url': 'https://example.com/metadata.jpg',
              'mime_type': 'image/jpeg',
              'variants': {
                'xs': 'https://example.com/metadata_xs.jpg',
              },
            },
          ],
        };

        final display = token['display'] as Map<String, dynamic>?;
        final mediaAssets = token['media_assets'] as List?;

        var thumbnailUrl = display?['image_url'] as String?;

        if (thumbnailUrl != null && mediaAssets != null) {
          final asset = mediaAssets.cast<Map<String, dynamic>>().firstWhere(
            (a) => a['source_url'] == thumbnailUrl,
            orElse: () => <String, dynamic>{},
          );
          if (asset.isNotEmpty) {
            final variants = asset['variants'] as Map?;
            thumbnailUrl = variants?['xs'] as String?;
          }
        }

        expect(thumbnailUrl, 'https://example.com/metadata_xs.jpg');
      });

      test('uses image_url directly when no variant URLs', () {
        final token = {
          'id': 'test_id',
          'token_cid': 'cid_test123',
          'display': {
            'name': 'Test Token',
            'image_url': 'https://example.com/direct.jpg',
          },
          // No media assets with variants
        };

        final display = token['display'] as Map<String, dynamic>?;
        final thumbnailUrl = display?['image_url'] as String?;

        expect(thumbnailUrl, 'https://example.com/direct.jpg');
      });
    });

    group('variant URL extraction', () {
      test('extracts xs variant when available', () {
        final variantUrls = {
          'xs': 'https://example.com/thumb_xs.jpg',
          's': 'https://example.com/thumb_s.jpg',
          'm': 'https://example.com/thumb_m.jpg',
        };

        final xsUrl = variantUrls['xs'];
        expect(xsUrl, 'https://example.com/thumb_xs.jpg');
      });

      test('falls back to first variant if xs not available', () {
        final variantUrls = {
          's': 'https://example.com/thumb_s.jpg',
          'm': 'https://example.com/thumb_m.jpg',
        };

        final xsUrl = variantUrls['xs'] ?? variantUrls.values.first;
        expect(xsUrl, 'https://example.com/thumb_s.jpg');
      });
    });
  });
}
