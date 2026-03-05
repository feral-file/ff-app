import 'dart:async';

import 'package:app/app/providers/addresses_provider.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake [AppStateService] that exposes controlled [watchTrackedAddressesAsWalletAddresses].
class _FakeAppStateServiceForAddresses implements AppStateService {
  List<WalletAddress> _addresses = [];

  set addresses(List<WalletAddress> value) => _addresses = value;

  @override
  Stream<List<WalletAddress>> watchTrackedAddressesAsWalletAddresses() async* {
    yield [];
    yield List.from(_addresses);
  }

  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {}

  @override
  Future<void> addTrackedAddress(String address, {String alias = ''}) async {}

  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) =>
      Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'addressesProvider maps ObjectBox address entities to wallet addresses',
      () async {
    final fake = _FakeAppStateServiceForAddresses();

    final container = ProviderContainer.test(
      overrides: [
        appStateServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final completer = Completer<List<WalletAddress>>();
    final sub = container.listen<AsyncValue<List<WalletAddress>>>(
      addressesProvider,
      (_, next) {
        next.whenData((value) {
          if (value.isNotEmpty && !completer.isCompleted) {
            completer.complete(value);
          }
        });
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    fake.addresses = [
      WalletAddress(
        address: '0xabc',
        name: 'Address A',
        createdAt: DateTime.now(),
      ),
    ];

    final addresses = await completer.future;
    expect(addresses.length, 1);
    expect(addresses.first.address, '0xabc');
    expect(addresses.first.name, 'Address A');
  });
}
