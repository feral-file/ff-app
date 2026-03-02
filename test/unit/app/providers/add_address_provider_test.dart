import 'package:app/app/providers/add_address_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDomainAddressService implements DomainAddressService {
  _FakeDomainAddressService(this._result);

  final Address? _result;

  @override
  Future<Address?> verifyAddressOrDomain(String value) async => _result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAddressService implements AddressService {
  _FakeAddressService({
    required this.isAlreadyAdded,
  });

  final bool isAlreadyAdded;
  String? lastCheckedAddress;
  Chain? lastCheckedChain;

  @override
  Future<bool> isAddressAlreadyAdded({
    required String address,
    required Chain chain,
  }) async {
    lastCheckedAddress = address;
    lastCheckedChain = chain;
    return isAlreadyAdded;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('addAddress and addAlias providers start idle', () {
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final addAddress = container.read(addAddressProvider);
    final addAlias = container.read(addAliasProvider);
    expect(addAddress.hasValue, isTrue);
    expect(addAddress.value, isNull);
    expect(addAlias.hasValue, isTrue);
  });

  group('AddAddressNotifier.verify', () {
    test('emits invalidAddressOrDomain when verification fails', () async {
      final container = ProviderContainer.test(
        overrides: [
          domainAddressServiceProvider.overrideWithValue(
            _FakeDomainAddressService(null),
          ),
          addressServiceProvider.overrideWithValue(
            _FakeAddressService(isAlreadyAdded: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(addAddressProvider, (_, _) {});
      addTearDown(keepAlive.close);

      await container.read(addAddressProvider.notifier).verify('bad-input');
      final state = container.read(addAddressProvider);

      expect(state.hasError, isTrue);
      expect(
        state.error,
        isA<AddAddressException>().having(
          (e) => e.type,
          'type',
          AddAddressExceptionType.invalidAddressOrDomain,
        ),
      );
    });

    test(
      'emits alreadyAdded when address exists (including pending)',
      () async {
        final resolved = Address(
          address: '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8',
          type: Chain.ethereum,
        );

        final fakeAddressService = _FakeAddressService(isAlreadyAdded: true);

        final container = ProviderContainer.test(
          overrides: [
            domainAddressServiceProvider.overrideWithValue(
              _FakeDomainAddressService(resolved),
            ),
            addressServiceProvider.overrideWithValue(fakeAddressService),
          ],
        );
        addTearDown(container.dispose);

        final keepAlive = container.listen(addAddressProvider, (_, _) {});
        addTearDown(keepAlive.close);

        await container.read(addAddressProvider.notifier).verify('anything');
        final state = container.read(addAddressProvider);

        expect(fakeAddressService.lastCheckedAddress, resolved.address);
        expect(fakeAddressService.lastCheckedChain, resolved.type);
        expect(
          state.error,
          isA<AddAddressException>().having(
            (e) => e.type,
            'type',
            AddAddressExceptionType.alreadyAdded,
          ),
        );
      },
    );

    test('returns Address when valid and not already added', () async {
      final resolved = Address(
        address: 'tz1ABC',
        type: Chain.tezos,
      );

      final container = ProviderContainer.test(
        overrides: [
          domainAddressServiceProvider.overrideWithValue(
            _FakeDomainAddressService(resolved),
          ),
          addressServiceProvider.overrideWithValue(
            _FakeAddressService(isAlreadyAdded: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final keepAlive = container.listen(addAddressProvider, (_, _) {});
      addTearDown(keepAlive.close);

      await container.read(addAddressProvider.notifier).verify('anything');
      final state = container.read(addAddressProvider);

      expect(state.hasValue, isTrue);
      expect(state.value?.address, resolved.address);
      expect(state.value?.type, resolved.type);
    });
  });
}
