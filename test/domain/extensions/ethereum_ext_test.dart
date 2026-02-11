import 'package:app/domain/extensions/ethereum_ext.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EthereumExtension.toEthereumAddress', () {
    test('returns null for non-ethereum input without throwing', () {
      expect(
        () => 'TZ1YHWTCRD9LKR1RTD3WDCCZ2CENWASS2LND'.toEthereumAddress(),
        returnsNormally,
      );
      expect(
        'TZ1YHWTCRD9LKR1RTD3WDCCZ2CENWASS2LND'.toEthereumAddress(),
        isNull,
      );
    });

    test('parses a valid ethereum address', () {
      expect(
        '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8'.toEthereumAddress(),
        isNotNull,
      );
    });
  });
}
