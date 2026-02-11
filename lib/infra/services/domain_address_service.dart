import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/services/domain_service.dart';
import 'package:wallet/wallet.dart' as wallet;

/// Service for verifying domain addresses
abstract class DomainAddressService {
  /// Verify an Ethereum address
  String? verifyEthereumAddress(String value);

  /// Verify a Tezos address
  String? verifyTezosAddress(String value);

  /// Verify an ENS domain
  Future<String?> verifyENS(String value);

  /// Verify a TNS domain
  Future<String?> verifyTNS(String value);

  /// Verify an address or domain
  Future<Address?> verifyAddressOrDomain(String value);
}

/// Implementation of DomainAddressService
class DomainAddressServiceImpl implements DomainAddressService {
  /// Create a DomainAddressServiceImpl
  DomainAddressServiceImpl(this._domainService);

  final DomainService _domainService;

  Address? _verifyAddress(String value) {
    final ethAddress = verifyEthereumAddress(value);
    if (ethAddress != null) {
      return Address(address: ethAddress, type: Chain.ethereum);
    }
    final tezosAddress = verifyTezosAddress(value);
    if (tezosAddress != null) {
      return Address(address: tezosAddress, type: Chain.tezos);
    }
    return null;
  }

  Future<Address?> _verifyDomain(String value) async {
    final isENSFormat = value.isENSFormat();
    if (isENSFormat) {
      final ethAddress = await verifyENS(value);
      if (ethAddress != null) {
        final checksumAddress = verifyEthereumAddress(ethAddress);
        if (checksumAddress != null) {
          return Address(
            address: checksumAddress,
            type: Chain.ethereum,
            domain: value,
          );
        }
      }
    } else if (value.isTNSFormat()) {
      final tezosAddress = await verifyTNS(value);
      if (tezosAddress != null) {
        final checksumAddress = verifyTezosAddress(tezosAddress);
        if (checksumAddress != null) {
          return Address(
            address: checksumAddress,
            type: Chain.tezos,
            domain: value,
          );
        }
      }
    }
    return null;
  }

  @override
  String? verifyEthereumAddress(String address) {
    try {
      if (!address.isEthereumAddressFormat()) {
        return null;
      }
      final checksumAddress =
          wallet.EthereumAddress.fromHex(address, enforceEip55: true);
      return checksumAddress.eip55With0x;
    } on Exception {
      return null;
    }
  }

  @override
  String? verifyTezosAddress(String address) {
    if (!address.isTezosAddressFormat()) {
      return null;
    }
    return address.isValidTezosAddress ? address : null;
  }

  @override
  Future<String?> verifyENS(String value) async {
    return _domainService.getAddress(value, chain: Chain.ethereum);
  }

  @override
  Future<String?> verifyTNS(String value) async {
    return _domainService.getAddress(value, chain: Chain.tezos);
  }

  @override
  Future<Address?> verifyAddressOrDomain(String value) async {
    final address = _verifyAddress(value);
    if (address != null) {
      return address;
    }
    return _verifyDomain(value);
  }
}
