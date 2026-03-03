import 'package:app/domain/utils/version_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersion', () {
    test('returns 0 when versions are equal', () {
      expect(compareVersion('1.0.0', '1.0.0'), 0);
      expect(compareVersion('1.0.5(123)', '1.0.5(123)'), 0);
    });

    test('returns positive when first version is greater', () {
      expect(compareVersion('1.0.1', '1.0.0'), greaterThan(0));
      expect(compareVersion('1.1.0', '1.0.9'), greaterThan(0));
      expect(compareVersion('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersion('1.0.5(124)', '1.0.5(123)'), greaterThan(0));
    });

    test('returns negative when first version is less', () {
      expect(compareVersion('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersion('1.0.9', '1.1.0'), lessThan(0));
      expect(compareVersion('1.0.5(123)', '1.0.5(124)'), lessThan(0));
    });

    test('handles build number in parentheses', () {
      expect(compareVersion('1.0.0(1)', '1.0.0'), greaterThan(0));
      expect(compareVersion('1.0.0', '1.0.0(1)'), lessThan(0));
    });

    test('handles whitespace', () {
      expect(compareVersion(' 1.0.0 ', '1.0.0'), 0);
    });
  });
}
