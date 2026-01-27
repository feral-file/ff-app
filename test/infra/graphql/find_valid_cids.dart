import 'package:app/infra/graphql/indexer_client.dart';

/// Quick script to find valid CIDs from the indexer
/// Run with: dart run test/infra/graphql/find_valid_cids.dart
void main() async {
  final client = IndexerClient(
    endpoint: 'https://indexer-v2.feralfile.com/graphql',
    defaultHeaders: {
      'Authorization': 'Bearer VU8ccCWdKoJE6B3+bZ9Tw9DcKX2FMml/wphy3aNiTe4=',
    },
  );

  print('Fetching tokens from Feral File treasury address...\n');

  // Feral File treasury address
  final addresses = ['0x4ad9298f8Eb285CC3867E89800c0d668B5d447a0'];

  try {
    final tokens = await client.fetchTokensByAddresses(
      addresses: addresses,
      limit: 5,
    );

    print('Found ${tokens.length} tokens\n');

    for (var i = 0; i < tokens.length && i < 5; i++) {
      final token = tokens[i];
      print('=== Token $i ===');
      print('Token CID: ${token['token_cid']}');
      print('Title: ${token['title']}');
      print('Thumbnail: ${token['thumbnailUrl']}');
      print('');
    }

    if (tokens.isNotEmpty) {
      print('\n✅ Use these CIDs for testing:');
      for (var i = 0; i < tokens.length && i < 3; i++) {
        print("  '${tokens[i]['token_cid']}',");
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
