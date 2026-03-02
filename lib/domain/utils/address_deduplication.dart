import 'package:app/domain/models/wallet_address.dart';

/// Normalization utilities for comparing user-entered addresses.
///
/// This is intentionally strict and deterministic so it can be used in both
/// UI/provider validation and persistence deduplication checks.
extension AddressDeduplicationStringExtension on String {
  /// Normalizes this address for equality comparison.
  ///
  /// - Ethereum: trims, normalizes `0X` → `0x`, lowercases.
  /// - Tezos/other: trims only (case-sensitive).
  String normalizeForComparison({
    required Chain chain,
  }) {
    final trimmed = trim();

    if (chain == Chain.ethereum) {
      final with0x = trimmed.startsWith('0X')
          ? '0x${trimmed.substring(2)}'
          : trimmed;
      return with0x.toLowerCase();
    }

    return trimmed;
  }

  /// Returns true when this address should be treated as [other].
  bool equalsAddress(
    String other, {
    required Chain chain,
  }) {
    return normalizeForComparison(chain: chain) ==
        other.normalizeForComparison(chain: chain);
  }
}
