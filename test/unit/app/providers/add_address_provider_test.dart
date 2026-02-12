import 'package:app/app/providers/add_address_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('addAddress and addAlias providers start idle', () {
    // Unit test: verifies both add-address providers initialize with neutral AsyncValue.
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final addAddress = container.read(addAddressProvider);
    final addAlias = container.read(addAliasProvider);
    expect(addAddress.hasValue, isTrue);
    expect(addAddress.value, isNull);
    expect(addAlias.hasValue, isTrue);
  });
}
