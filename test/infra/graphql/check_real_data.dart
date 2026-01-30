/// Quick script to test with real API data
/// Run with: dart run test/infra/graphql/check_real_data.dart
import 'package:app/domain/extensions/asset_token_ext.dart';
import 'package:app/infra/graphql/indexer_client.dart';

void main() async {
  final client = IndexerClient(
    endpoint: 'https://indexer-v2.feralfile.com/graphql',
    defaultHeaders: {
      'Authorization': 'Bearer VU8ccCWdKoJE6B3+bZ9Tw9DcKX2FMml/wphy3aNiTe4=',
    },
  );

  print('Testing with a known address from Feral File...');

  // Use a known Feral File address that likely has tokens
  final addresses = [
    '0x99d8a9c45b2eca8864373a26d1459e3dff1e17f3', // Feral File treasury
  ];

  print('\n=== Fetching tokens by addresses ===');
  print('Addresses: $addresses');

  try {
    final tokens = await client.fetchTokensByAddresses(
      addresses: addresses,
      limit: 2,
    );

    print('\n=== Response ===');
    print('Number of tokens: ${tokens.length}');

    if (tokens.isNotEmpty) {
      final token = tokens.first;
      print('\n=== First Token ===');
      print('ID: ${token.id}');
      print('CID: ${token.cid}');
      print('Title: ${token.displayTitle}');
      final thumbnailUrl = token.getGalleryThumbnailUrl();
      final previewUrl =
          token.enrichmentSource?.animationUrl ?? token.metadata?.animationUrl;
      print('Thumbnail URL: $thumbnailUrl');
      print('Preview URL: $previewUrl');

      if (thumbnailUrl != null) {
        print('\n✅ SUCCESS: Found thumbnail!');
      } else {
        print('\n❌ FAIL: No thumbnail');
        print('\nDebugging info:');
        print('Metadata: ${token.metadata?.toJson()}');
        print('Enrichment: ${token.enrichmentSource?.toJson()}');
      }
    } else {
      print('\n⚠️  No tokens returned');
    }
  } catch (e) {
    print('\n❌ ERROR: $e');
  }
}
