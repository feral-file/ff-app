import 'package:crypto/crypto.dart';
import 'package:fast_base58/fast_base58.dart';
import 'package:flutter/foundation.dart';

/// Extension methods for Tezos
extension TezosExtension on String {
  /// Check if the string is a valid Tezos address
  bool get isValidTezosAddress {
    try {
      final decoded = Base58Decode(this);
      if (decoded.length < 4) {
        return false;
      }
      final checksum = sha256
          .convert(sha256.convert(decoded.sublist(0, decoded.length - 4)).bytes)
          .bytes
          .sublist(0, 4);
      return listEquals(checksum, decoded.sublist(decoded.length - 4));
    } catch (_) {
      return false;
    }
  }

  /// Check if the string is a Tezos address format
  bool isTezosAddressFormat() {
    final regex = RegExp(r'^(tz1|tz2|tz3|KT1)[1-9A-HJ-NP-Za-km-z]{33}$');
    return regex.hasMatch(this);
  }

  /// Check if the string is a TNS format (Tezos Name Service)
  bool isTNSFormat() {
    final regex = RegExp(r'^[^\s]+\.tez$', caseSensitive: false);
    return regex.hasMatch(this);
  }
}
