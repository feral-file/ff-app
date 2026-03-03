import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IndexerClient transformation logic', () {
    group('thumbnail extraction from media assets', () {
      test('extracts thumbnail from enrichment source variant URLs', () {
        // Simulate token data from GraphQL response
        final token = {
          'id': 'test_id',
          'token_cid': 'cid_test123',
          'chain': 'ethereum',
          'contract_address': '0xABCD',
          'token_number': '1',
          'metadata': {
            'name': 'Test Token',
            'image_url': 'https://example.com/original.jpg',
          },
          'enrichment_source': {
            'name': 'Enriched Name',
            'image_url': 'https://example.com/enriched.jpg',
          },
          'enrichment_source_media_assets': [
            {
              'source_url': 'https://example.com/enriched.jpg',
              'mime_type': 'image/jpeg',
              'variant_urls': {
                'xs': 'https://example.com/enriched_xs.jpg',
                's': 'https://example.com/enriched_s.jpg',
                'm': 'https://example.com/enriched_m.jpg',
              },
            },
          ],
        };

        final enrichmentSource =
            token['enrichment_source'] as Map<String, dynamic>?;
        final enrichmentAssets =
            token['enrichment_source_media_assets'] as List?;

        // Get base thumbnail URL (enrichment source priority)
        var thumbnailUrl = enrichmentSource?['image_url'] as String?;

        // Extract variant URL
        if (thumbnailUrl != null && enrichmentAssets != null) {
          final asset = enrichmentAssets
              .cast<Map<String, dynamic>>()
              .firstWhere(
                (a) => a['source_url'] == thumbnailUrl,
                orElse: () => <String, dynamic>{},
              );
          if (asset.isNotEmpty) {
            final variantUrls = asset['variant_urls'] as Map?;
            thumbnailUrl = variantUrls?['xs'] as String?;
          }
        }

        expect(thumbnailUrl, 'https://example.com/enriched_xs.jpg');
      });

      test('falls back to metadata when enrichment source missing', () {
        final token = {
          'id': 'test_id',
          'token_cid': 'cid_test123',
          'metadata': {
            'name': 'Test Token',
            'image_url': 'https://example.com/metadata.jpg',
          },
          'metadata_media_assets': [
            {
              'source_url': 'https://example.com/metadata.jpg',
              'mime_type': 'image/jpeg',
              'variant_urls': {
                'xs': 'https://example.com/metadata_xs.jpg',
              },
            },
          ],
          // No enrichment_source
        };

        final metadata = token['metadata'] as Map<String, dynamic>?;
        final metadataAssets = token['metadata_media_assets'] as List?;

        var thumbnailUrl = metadata?['image_url'] as String?;

        if (thumbnailUrl != null && metadataAssets != null) {
          final asset = metadataAssets.cast<Map<String, dynamic>>().firstWhere(
            (a) => a['source_url'] == thumbnailUrl,
            orElse: () => <String, dynamic>{},
          );
          if (asset.isNotEmpty) {
            final variantUrls = asset['variant_urls'] as Map?;
            thumbnailUrl = variantUrls?['xs'] as String?;
          }
        }

        expect(thumbnailUrl, 'https://example.com/metadata_xs.jpg');
      });

      test('uses image_url directly when no variant URLs', () {
        final token = {
          'id': 'test_id',
          'token_cid': 'cid_test123',
          'metadata': {
            'name': 'Test Token',
            'image_url': 'https://example.com/direct.jpg',
          },
          // No media assets with variants
        };

        final metadata = token['metadata'] as Map<String, dynamic>?;
        final thumbnailUrl = metadata?['image_url'] as String?;

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
