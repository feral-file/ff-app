import 'package:app/domain/models/wallet_address.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('String.normalizeForComparison', () {
    test('trims whitespace for all chains', () {
      expect(
        '  tz1ABC  '.normalizeForComparison(chain: Chain.tezos),
        'tz1ABC',
      );
    });

    test('normalizes Ethereum 0X prefix and lowercases', () {
      expect(
        '  0X99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8  '.normalizeForComparison(
          chain: Chain.ethereum,
        ),
        '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
      );
    });

    test('leaves Tezos casing intact (after trim)', () {
      expect(
        'TZ1Test'.normalizeForComparison(chain: Chain.tezos),
        'TZ1Test',
      );
    });
  });

  group('String.equalsAddress', () {
    test('compares Ethereum addresses case-insensitively', () {
      expect(
        '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8'.equalsAddress(
          '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
          chain: Chain.ethereum,
        ),
        isTrue,
      );
    });

    test('compares Tezos addresses exactly (after trim)', () {
      expect(
        'tz1ABC'.equalsAddress(
          'tz1ABC',
          chain: Chain.tezos,
        ),
        isTrue,
      );
      expect(
        'tz1ABC'.equalsAddress(
          'TZ1ABC',
          chain: Chain.tezos,
        ),
        isFalse,
      );
    });
  });
}
