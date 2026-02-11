import 'package:wallet/wallet.dart';

/// Extension methods for Ethereum
extension EthereumExtension on String {
  /// Convert the string to an Ethereum address
  EthereumAddress? toEthereumAddress({bool isChecksum = false}) {
    try {
      final address = EthereumAddress.fromHex(this, enforceEip55: isChecksum);
      return address;
    } on Object {
      return null;
    }
  }

  /// Check if the string is a null address
  bool get isNullAddress {
    return this == '0x0000000000000000000000000000000000000000';
  }

  /// Check if the string is an Ethereum address format
  bool isEthereumAddressFormat() {
    final regex = RegExp(r'^(0x[a-fA-F0-9]{40})$');
    return regex.hasMatch(this);
  }

  /// Check if the string is an ENS format (Ethereum Name Service)
  bool isENSFormat() {
    final regex = RegExp(r'^[^\s]+\.eth$', caseSensitive: false);
    return regex.hasMatch(this);
  }
}
