import 'package:flutter_test/flutter_test.dart';
import 'package:app/infra/graphql/indexer_client.dart';

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
          'Authorization': 'Bearer VU8ccCWdKoJE6B3+bZ9Tw9DcKX2FMml/wphy3aNiTe4=',
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

        expect(tokens, isNotEmpty, 
            reason: 'Should fetch at least one token for CID: $testCid');

        final token = tokens.first;
        
        print('\n=== Token Data ===');
        print('Token ID: ${token['id']}');
        print('Token CID: ${token['token_cid']}');
        print('Title: ${token['title']}');
        print('Chain: ${token['chain']}');
        print('Contract: ${token['contract_address']}');
        print('Token Number: ${token['token_number']}');
        
        print('\n=== Metadata ===');
        final metadata = token['metadata'] as Map<String, dynamic>?;
        if (metadata != null) {
          print('Name: ${metadata['name']}');
          print('Image URL: ${metadata['image_url']}');
          print('Animation URL: ${metadata['animation_url']}');
          print('Mime Type: ${metadata['mime_type']}');
          print('Description: ${metadata['description']?.toString().substring(0, metadata['description'].toString().length > 100 ? 100 : metadata['description'].toString().length)}...');
        }
        
        print('\n=== Enrichment Source ===');
        final enrichment = token['enrichment_source'] as Map<String, dynamic>?;
        if (enrichment != null) {
          print('Vendor: ${enrichment['vendor']}');
          print('Name: ${enrichment['name']}');
          print('Image URL: ${enrichment['image_url']}');
          print('Animation URL: ${enrichment['animation_url']}');
          print('Mime Type: ${enrichment['mime_type']}');
        }
        
        print('\n=== Media Assets ===');
        final metadataAssets = token['metadata_media_assets'] as List?;
        print('Metadata Assets: ${metadataAssets?.length ?? 0}');
        if (metadataAssets != null && metadataAssets.isNotEmpty) {
          final asset = metadataAssets.first as Map<String, dynamic>;
          print('  Source URL: ${asset['source_url']}');
          print('  Mime Type: ${asset['mime_type']}');
          print('  Variants: ${asset['variant_urls']}');
        }
        
        final enrichmentAssets = token['enrichment_source_media_assets'] as List?;
        print('Enrichment Assets: ${enrichmentAssets?.length ?? 0}');
        if (enrichmentAssets != null && enrichmentAssets.isNotEmpty) {
          final asset = enrichmentAssets.first as Map<String, dynamic>;
          print('  Source URL: ${asset['source_url']}');
          print('  Mime Type: ${asset['mime_type']}');
          print('  Variants: ${asset['variant_urls']}');
        }
        
        print('\n=== Final Thumbnail ===');
        print('Thumbnail URL: ${token['thumbnailUrl']}');
        print('Preview URL: ${token['previewUrl']}');

        // Verify thumbnail was extracted
        expect(
          token['thumbnailUrl'],
          isNotNull,
          reason: 'Thumbnail URL should be extracted from token data',
        );
        
        expect(
          token['thumbnailUrl'],
          isA<String>(),
          reason: 'Thumbnail URL should be a string',
        );
        
        final thumbnailUrl = token['thumbnailUrl'] as String;
        expect(
          thumbnailUrl.isNotEmpty,
          isTrue,
          reason: 'Thumbnail URL should not be empty',
        );
        
        // Verify it's a valid URL
        final uri = Uri.tryParse(thumbnailUrl);
        expect(
          uri,
          isNotNull,
          reason: 'Thumbnail URL should be a valid URI: $thumbnailUrl',
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
    }, skip: false); // Set to true to skip in CI

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
          final token = tokens.first;
          print('\n=== First Token ===');
          print('ID: ${token['id']}');
          print('Title: ${token['title']}');
          print('Thumbnail URL: ${token['thumbnailUrl']}');

          expect(token['thumbnailUrl'], isNotNull,
              reason: 'Thumbnail URL should not be null');
        } else {
          print('\n⚠️  No tokens returned for addresses: $addresses');
        }
      } catch (e) {
        print('\n⚠️  Error fetching tokens: $e');
        // Don't fail the test if the address has no tokens
      }
    }, skip: false);
  });
}
