import 'package:app/domain/models/wallet_address.dart';

/// Normalization utilities for comparing user-entered addresses.
///
/// This is intentionally strict and deterministic so it can be used in both
/// UI/provider validation and persistence deduplication checks.
extension AddressDeduplicationStringExtension on String {
  /// Returns a canonical normalized form for storage and key lookups.
  ///
  /// Use when you need a single canonical string regardless of input format
  /// (checksummed, mixed case, etc.). Derives chain from address shape.
  ///
  /// - Ethereum (0x/0X...): lowercase hex
  /// - Tezos: trimmed (case-sensitive)
  /// - Special keys like `FEED::...`: returned as-is
  String toNormalizedAddress() {
    final trimmed = trim();
    if (trimmed.startsWith('FEED::')) return trimmed;
    // Treat 0x-prefixed as Ethereum for normalization (even if not valid 40-char).
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return '0x${trimmed.substring(2).toLowerCase()}';
    }
    return normalizeForComparison(chain: Chain.fromAddress(trimmed));
  }

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
