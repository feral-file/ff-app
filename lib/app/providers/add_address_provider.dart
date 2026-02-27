import 'dart:async';

import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('AddAddressProvider');

/// Notifier for adding address
class AddAddressNotifier extends AsyncNotifier<Address?> {
  @override
  FutureOr<Address?> build() {
    return null;
  }

  /// Verify address
  Future<void> verify(String addressOrDomain) async {
    state = const AsyncValue.loading();

    try {
      // Validate address or domain via DomainAddressService
      final domainAddressService = ref.read(domainAddressServiceProvider);
      final addressInfo = await domainAddressService.verifyAddressOrDomain(
        addressOrDomain,
      );
      if (addressInfo == null) {
        throw Exception('Invalid address or domain');
      }

      _log.info('Address verified: ${addressInfo.address} ');

      state = AsyncValue.data(addressInfo);
    } on Exception catch (e, stack) {
      _log.severe('Failed to verify address: $addressOrDomain', e, stack);
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Provider for adding address
final AsyncNotifierProvider<AddAddressNotifier, Address?> addAddressProvider =
    AsyncNotifierProvider.autoDispose<AddAddressNotifier, Address?>(
      AddAddressNotifier.new,
    );

/// Notifier for adding alias
class AddAliasNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    return null;
  }

  /// Add address with alias
  Future<void> add(
    String address,
    String? alias, {
    bool syncNow = true,
  }) async {
    state = const AsyncValue.loading();

    try {
      final normalizedAddress = address.trim();
      final name = (alias?.isEmpty ?? false)
          ? normalizedAddress.shortenAddress()
          : alias;
      final walletAddress = WalletAddress(
        address: normalizedAddress,
        createdAt: DateTime.now(),
        name: name,
      );

      final addressService = ref.read(addressServiceProvider);
      await addressService.addAddress(
        walletAddress: walletAddress,
        syncNow: syncNow,
      );

      _log.info(
        'Successfully added address: ${walletAddress.address}, name: $name',
      );

      state = const AsyncValue.data(null);
    } on Exception catch (e, stack) {
      _log.severe('Failed to add address: $address', e, stack);
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Provider for adding alias
final AsyncNotifierProvider<AddAliasNotifier, void> addAliasProvider =
    AsyncNotifierProvider.autoDispose<AddAliasNotifier, void>(
      AddAliasNotifier.new,
    );
