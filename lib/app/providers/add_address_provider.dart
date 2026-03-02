import 'dart:async';

import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('AddAddressProvider');

/// Error categories for the add-address flow.
enum AddAddressExceptionType {
  /// The input is not a valid address and cannot be resolved as a domain.
  invalidAddressOrDomain,

  /// The resolved address is already added (including pending addresses).
  alreadyAdded;

  /// A user-facing message suitable for inline UI.
  String get message {
    return switch (this) {
      AddAddressExceptionType.invalidAddressOrDomain =>
        "We couldn't validate this address. Check it and try again.",
      AddAddressExceptionType.alreadyAdded =>
        'This address is already added. Enter a different address.',
    };
  }
}

/// Exception thrown for expected, user-facing add-address validation failures.
class AddAddressException implements Exception {
  /// Creates an [AddAddressException] of the given [type].
  AddAddressException({
    required this.type,
  });

  /// Error category for UI messaging and branching.
  final AddAddressExceptionType type;

  /// A user-facing message suitable for inline UI.
  String get message => type.message;

  @override
  String toString() => message;
}

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
        throw AddAddressException(
          type: AddAddressExceptionType.invalidAddressOrDomain,
        );
      }

      final addressService = ref.read(addressServiceProvider);
      final alreadyAdded = await addressService.isAddressAlreadyAdded(
        address: addressInfo.address,
        chain: addressInfo.type,
      );
      if (alreadyAdded) {
        throw AddAddressException(type: AddAddressExceptionType.alreadyAdded);
      }

      _log.info('Address verified: ${addressInfo.address} ');

      state = AsyncValue.data(addressInfo);
    } on Exception catch (e, stack) {
      if (e is AddAddressException) {
        _log.info('Add-address blocked: ${e.type.name}');
      } else {
        _log.severe('Failed to verify address: $addressOrDomain', e, stack);
      }
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
