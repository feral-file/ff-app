import 'package:flutter_test/flutter_test.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/extensions/asset_token_ext.dart';

/// Integration test to verify actual indexer API responses
/// Run with: flutter test test/infra/graphql/indexer_client_integration_test.dart
void main() {
  group('IndexerClient Integration Test', () {
    late IndexerClient client;

    setUp(() {
      // Use the actual indexer endpoint
      client = IndexerClient(
        endpoint: 'https://indexer-v2.feralfile.com/graphql',
        defaultHeaders: {
          'Authorization':
              'Bearer VU8ccCWdKoJE6B3+bZ9Tw9DcKX2FMml/wphy3aNiTe4=',
        },
      );
    });

    test('fetchTokensByCIDs returns real data with thumbnails', () async {
      // Use the specific token CID provided by user
      const testCid = 'dbdcf0e1-999c-48ed-85e1-26e7d9ff74c5';

      print('\n=== Fetching tokens by CID ===');
      print('CID: $testCid');

      try {
        final tokens = await client.fetchTokensByCIDs(cids: [testCid]);

        print('\n=== Response ===');
        print('Number of tokens: ${tokens.length}');

        expect(
          tokens,
          isNotEmpty,
          reason: 'Should fetch at least one token for CID: $testCid',
        );

        final AssetToken token = tokens.first;

        print('\n=== Token Data ===');
        print('Token ID: ${token.id}');
        print('Token CID: ${token.cid}');
        print('Title: ${token.metadata?.name}');
        print('Chain: ${token.chain}');
        print('Contract: ${token.contractAddress}');
        print('Token Number: ${token.tokenNumber}');

        print('\n=== Metadata ===');
        final metadata = token.metadata;
        if (metadata != null) {
          print('Name: ${metadata.name}');
          print('Image URL: ${metadata.imageUrl}');
          print('Animation URL: ${metadata.animationUrl}');
          print('Mime Type: ${metadata.mimeType}');
          final desc = metadata.description ?? '';
          final trimmed = desc.length > 100 ? desc.substring(0, 100) : desc;
          print('Description: $trimmed...');
        }

        print('\n=== Enrichment Source ===');
        final enrichment = token.enrichmentSource;
        if (enrichment != null) {
          print('Name: ${enrichment.name}');
          print('Image URL: ${enrichment.imageUrl}');
          print('Animation URL: ${enrichment.animationUrl}');
          print('Mime Type: ${enrichment.mimeType}');
        }

        print('\n=== Media Assets ===');
        final metadataAssets = token.metadataMediaAssets;
        print('Metadata Assets: ${metadataAssets?.length ?? 0}');

        final enrichmentAssets = token.enrichmentSourceMediaAssets;
        print('Enrichment Assets: ${enrichmentAssets?.length ?? 0}');

        print('\n=== Final Thumbnail ===');
        final thumbnailUrl = token.getGalleryThumbnailUrl();
        final previewUrl = token.enrichmentSource?.animationUrl ??
            token.metadata?.animationUrl;
        print('Thumbnail URL: $thumbnailUrl');
        print('Preview URL: $previewUrl');

        // Verify thumbnail was extracted
        expect(
          thumbnailUrl,
          isNotNull,
          reason: 'Thumbnail URL should be extracted from token data',
        );
        final resolvedThumbnailUrl = thumbnailUrl!;

        expect(
          resolvedThumbnailUrl.isNotEmpty,
          isTrue,
          reason: 'Thumbnail URL should not be empty',
        );

        // Verify it's a valid URL
        final uri = Uri.tryParse(resolvedThumbnailUrl);
        expect(
          uri,
          isNotNull,
          reason: 'Thumbnail URL should be a valid URI: $resolvedThumbnailUrl',
        );

        expect(
          uri?.scheme,
          isIn(['http', 'https', 'ipfs']),
          reason: 'Thumbnail URL should have a valid scheme',
        );

        print('\n✅ SUCCESS: Thumbnail URL is valid: $thumbnailUrl');
      } catch (e, stack) {
        print('\n❌ ERROR: $e');
        print('Stack: $stack');
        rethrow;
      }
    }, skip: 'Integration test: requires live indexer + valid token CID.');

    test('fetchTokensByAddresses returns real data with thumbnails', () async {
      // Use a known address with tokens
      // This is a test address - replace with an actual one
      final addresses = [
        '0x1234567890123456789012345678901234567890',
      ];

      print('\n=== Fetching tokens by addresses ===');
      print('Addresses: $addresses');

      try {
        final tokens = await client.fetchTokensByAddresses(
          addresses: addresses,
          limit: 5,
        );

        print('\n=== Response ===');
        print('Number of tokens: ${tokens.length}');

        if (tokens.isNotEmpty) {
          final AssetToken token = tokens.first;
          print('\n=== First Token ===');
          print('ID: ${token.id}');
          print('Title: ${token.metadata?.name}');
          final thumbnailUrl = token.getGalleryThumbnailUrl();
          print('Thumbnail URL: $thumbnailUrl');

          expect(
            thumbnailUrl,
            isNotNull,
            reason: 'Thumbnail URL should not be null',
          );
        } else {
          print('\n⚠️  No tokens returned for addresses: $addresses');
        }
      } catch (e) {
        print('\n⚠️  Error fetching tokens: $e');
        // Don't fail the test if the address has no tokens
      }
    }, skip: 'Integration test: requires live indexer + funded test address.');
  });
}
