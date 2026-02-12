import 'package:app/app/providers/api_providers.dart';
import 'package:app/app/providers/indexer_provider.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test('fetchTokensByCIDsProvider delegates to indexer service', () async {
    // Unit test: verifies token CID fetch provider reads from injected indexer service.
    final fakeIndexer = FakeIndexerService(
      tokensByCid: [
        AssetToken(
          id: 1,
          cid: 'cid-1',
          chain: 'ethereum',
          standard: 'erc721',
          contractAddress: '0x1',
          tokenNumber: '1',
        ),
      ],
    );
    final container = ProviderContainer.test(
      overrides: [
        indexerServiceProvider.overrideWithValue(fakeIndexer),
      ],
    );
    addTearDown(container.dispose);

    final tokens = await container.read(
      fetchTokensByCIDsProvider(['cid-1']).future,
    );
    expect(tokens.length, 1);
    expect(fakeIndexer.lastTokenCids, ['cid-1']);
  });

  test('fetchTokensByAddressesProvider delegates to sync service', () async {
    // Unit test: verifies address-based token sync provider uses injected sync service.
    final fakeSync = FakeIndexerSyncService(nextCount: 7);
    final container = ProviderContainer.test(
      overrides: [
        indexerSyncServiceProvider.overrideWithValue(fakeSync),
      ],
    );
    addTearDown(container.dispose);

    final count = await container.read(
      fetchTokensByAddressesProvider(['0xabc']).future,
    );
    expect(count, 7);
    expect(fakeSync.lastAddresses, ['0xabc']);
  });
}
