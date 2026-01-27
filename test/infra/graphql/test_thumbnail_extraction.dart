import 'package:flutter_test/flutter_test.dart';
import 'package:app/infra/graphql/indexer_client.dart';

/// Comprehensive test for thumbnail extraction from indexer API
/// 
/// IMPORTANT: DP1 Items vs Token CIDs
/// - DP1 items have 'id' (UUID like dbdcf0e1-999c-48ed-85e1-26e7d9ff74c5)
/// - DP1 items have 'cid' (IPFS CID like bafybeic...)
/// - Indexer API only accepts IPFS CIDs, not UUIDs
/// 
/// Run with: flutter test test/infra/graphql/test_thumbnail_extraction.dart
void main() {
  group('Thumbnail Extraction Test', () {
    late IndexerClient client;

    setUp(() {
      client = IndexerClient(
        endpoint: 'https://indexer-v2.feralfile.com/graphql',
        defaultHeaders: {
          'Authorization': 'Bearer VU8ccCWdKoJE6B3+bZ9Tw9DcKX2FMml/wphy3aNiTe4=',
        },
      );
    });

    test('DEMO: UUID vs CID - this will fail as expected', () async {
      // This is a DP1 item ID (UUID), NOT a token CID
      const dp1ItemUuid = 'dbdcf0e1-999c-48ed-85e1-26e7d9ff74c5';

      print('\n❌ Testing with DP1 item UUID (should fail):');
      print('UUID: $dp1ItemUuid');

      try {
        await client.fetchTokensByCIDs(cids: [dp1ItemUuid]);
        fail('Should have thrown an exception for invalid CID');
      } catch (e) {
        print('\n✅ Expected error received:');
        print(e.toString().substring(0, 200));
        expect(
          e.toString(),
          contains('invalid token CID'),
          reason: 'Should reject UUID as invalid CID',
        );
      }
    });

    test('Fetch token with valid IPFS CID and verify thumbnail', () async {
      // This is a valid IPFS CID from Feral File production
      // Source: Sean's Feral File Classics playlist
      const validCid = 'bafkreif6ujsly5rz4etkeqkr3wgwfvhrmnynjb7jsjezh6skmhgvcwapby';

      print('\n✅ Testing with valid IPFS CID:');
      print('CID: $validCid');

      final tokens = await client.fetchTokensByCIDs(cids: [validCid]);

      expect(tokens, isNotEmpty, reason: 'Should return at least one token');

      final token = tokens.first;

      print('\n=== Token Information ===');
      print('Token ID: ${token['id']}');
      print('Token CID: ${token['token_cid']}');
      print('Chain: ${token['chain']}');
      print('Contract: ${token['contract_address']}');
      print('Token #: ${token['token_number']}');

      print('\n=== Metadata ===');
      final metadata = token['metadata'] as Map<String, dynamic>?;
      if (metadata != null) {
        print('Name: ${metadata['name']}');
        print('Image URL: ${metadata['image_url']}');
        print('Mime Type: ${metadata['mime_type']}');
      }

      print('\n=== Enrichment Source ===');
      final enrichment = token['enrichment_source'] as Map<String, dynamic>?;
      if (enrichment != null) {
        print('Vendor: ${enrichment['vendor']}');
        print('Name: ${enrichment['name']}');
        print('Image URL: ${enrichment['image_url']}');
        print('Mime Type: ${enrichment['mime_type']}');
      }

      print('\n=== Media Assets ===');
      final metadataAssets = token['metadata_media_assets'] as List?;
      print('Metadata Assets: ${metadataAssets?.length ?? 0}');
      if (metadataAssets != null && metadataAssets.isNotEmpty) {
        for (var i = 0; i < metadataAssets.length; i++) {
          final asset = metadataAssets[i] as Map<String, dynamic>;
          print('  [$i] Source: ${asset['source_url']}');
          print('      Variants: ${asset['variant_urls']}');
        }
      }

      final enrichmentAssets = token['enrichment_source_media_assets'] as List?;
      print('Enrichment Assets: ${enrichmentAssets?.length ?? 0}');
      if (enrichmentAssets != null && enrichmentAssets.isNotEmpty) {
        for (var i = 0; i < enrichmentAssets.length; i++) {
          final asset = enrichmentAssets[i] as Map<String, dynamic>;
          print('  [$i] Source: ${asset['source_url']}');
          print('      Variants: ${asset['variant_urls']}');
        }
      }

      print('\n=== Extracted Thumbnail ===');
      final thumbnailUrl = token['thumbnailUrl'] as String?;
      final previewUrl = token['previewUrl'] as String?;
      
      print('Thumbnail URL: $thumbnailUrl');
      print('Preview URL: $previewUrl');

      // Assertions
      expect(
        thumbnailUrl,
        isNotNull,
        reason: 'Thumbnail URL must be extracted',
      );

      expect(
        thumbnailUrl,
        isA<String>(),
        reason: 'Thumbnail URL must be a string',
      );

      expect(
        thumbnailUrl!.isNotEmpty,
        isTrue,
        reason: 'Thumbnail URL must not be empty',
      );

      final uri = Uri.tryParse(thumbnailUrl);
      expect(
        uri,
        isNotNull,
        reason: 'Thumbnail URL must be a valid URI',
      );

      expect(
        uri?.scheme,
        isIn(['http', 'https', 'ipfs']),
        reason: 'Thumbnail URL must have http/https/ipfs scheme',
      );

      print('\n✅ SUCCESS: Valid thumbnail extracted!');
      print('Final URL: $thumbnailUrl');
    });

    test('Fetch multiple tokens and verify all have thumbnails', () async {
      // Multiple valid CIDs from production
      final cids = [
        'bafkreif6ujsly5rz4etkeqkr3wgwfvhrmnynjb7jsjezh6skmhgvcwapby',
        'bafkreiajxbzkzutgzbvv7qqvzfteod2gnqnxk3iheq5k6h2j4z7fkx45ni',
      ];

      print('\n=== Testing multiple tokens ===');
      print('Fetching ${cids.length} tokens...');

      final tokens = await client.fetchTokensByCIDs(cids: cids);

      print('Received ${tokens.length} tokens\n');

      for (var i = 0; i < tokens.length; i++) {
        final token = tokens[i];
        final thumbnailUrl = token['thumbnailUrl'] as String?;
        
        print('[$i] CID: ${token['token_cid']}');
        print('    Title: ${token['title']}');
        print('    Thumbnail: $thumbnailUrl');

        expect(
          thumbnailUrl,
          isNotNull,
          reason: 'Token $i should have thumbnail URL',
        );
      }

      print('\n✅ All ${tokens.length} tokens have valid thumbnails!');
    });
  });
}
