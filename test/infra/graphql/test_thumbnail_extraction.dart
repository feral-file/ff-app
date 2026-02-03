import 'package:flutter_test/flutter_test.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/domain/extensions/asset_token_ext.dart';
import 'package:app/infra/services/indexer_service.dart';

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
    late IndexerService indexerService;

    setUp(() {
      client = IndexerClient(
        endpoint: 'https://indexer-v2.feralfile.com/graphql',
        defaultHeaders: {
          'Authorization':
              'Bearer VU8ccCWdKoJE6B3+bZ9Tw9DcKX2FMml/wphy3aNiTe4=',
        },
      );
      indexerService = IndexerService(
        client: client,
      );
    });

    test(
      'DEMO: UUID vs CID - this will fail as expected',
      () async {
        // This is a DP1 item ID (UUID), NOT a token CID
        const dp1ItemUuid = 'dbdcf0e1-999c-48ed-85e1-26e7d9ff74c5';

        print('\n❌ Testing with DP1 item UUID (should fail):');
        print('UUID: $dp1ItemUuid');

        try {
          await indexerService.fetchTokensByCIDs(cids: [dp1ItemUuid]);
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
      },
      skip: 'Integration test: requires live indexer.',
    );

    test(
      'Fetch token with valid IPFS CID and verify thumbnail',
      () async {
        // This is a valid IPFS CID from Feral File production
        // Source: Sean's Feral File Classics playlist
        const validCid =
            'bafkreif6ujsly5rz4etkeqkr3wgwfvhrmnynjb7jsjezh6skmhgvcwapby';

        print('\n✅ Testing with valid IPFS CID:');
        print('CID: $validCid');

        final tokens = await indexerService.fetchTokensByCIDs(cids: [validCid]);

        expect(tokens, isNotEmpty, reason: 'Should return at least one token');

        final token = tokens.first;

        print('\n=== Token Information ===');
        print('Token ID: ${token.id}');
        print('Token CID: ${token.cid}');
        print('Chain: ${token.chain}');
        print('Contract: ${token.contractAddress}');
        print('Token #: ${token.tokenNumber}');

        print('\n=== Metadata ===');
        final metadata = token.metadata;
        if (metadata != null) {
          print('Name: ${metadata.name}');
          print('Image URL: ${metadata.imageUrl}');
          print('Mime Type: ${metadata.mimeType}');
        }

        print('\n=== Enrichment Source ===');
        final enrichment = token.enrichmentSource;
        if (enrichment != null) {
          print('Name: ${enrichment.name}');
          print('Image URL: ${enrichment.imageUrl}');
          print('Mime Type: ${enrichment.mimeType}');
        }

        print('\n=== Media Assets ===');
        final metadataAssets = token.metadataMediaAssets;
        print('Metadata Assets: ${metadataAssets?.length ?? 0}');

        final enrichmentAssets = token.enrichmentSourceMediaAssets;
        print('Enrichment Assets: ${enrichmentAssets?.length ?? 0}');

        print('\n=== Extracted Thumbnail ===');
        final thumbnailUrl = token.getGalleryThumbnailUrl();
        final previewUrl = token.enrichmentSource?.animationUrl ??
            token.metadata?.animationUrl;

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
      },
      skip: 'Integration test: requires live indexer.',
    );

    test(
      'Fetch multiple tokens and verify all have thumbnails',
      () async {
        // Multiple valid CIDs from production
        final cids = [
          'bafkreif6ujsly5rz4etkeqkr3wgwfvhrmnynjb7jsjezh6skmhgvcwapby',
          'bafkreiajxbzkzutgzbvv7qqvzfteod2gnqnxk3iheq5k6h2j4z7fkx45ni',
        ];

        print('\n=== Testing multiple tokens ===');
        print('Fetching ${cids.length} tokens...');

        final tokens = await indexerService.fetchTokensByCIDs(cids: cids);

        print('Received ${tokens.length} tokens\n');

        for (var i = 0; i < tokens.length; i++) {
          final token = tokens[i];
          final thumbnailUrl = token.getGalleryThumbnailUrl();

          print('[$i] CID: ${token.cid}');
          print('    Title: ${token.metadata?.name}');
          print('    Thumbnail: $thumbnailUrl');

          expect(
            thumbnailUrl,
            isNotNull,
            reason: 'Token $i should have thumbnail URL',
          );
        }

        print('\n✅ All ${tokens.length} tokens have valid thumbnails!');
      },
      skip: 'Integration test: requires live indexer.',
    );
  });
}
