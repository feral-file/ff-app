import 'package:app/design/image_decode_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodePixelsForLogicalSize', () {
    test('matches physical pixels for common DPRs', () {
      expect(decodePixelsForLogicalSize(65.78, 2.0), 132);
      expect(decodePixelsForLogicalSize(37, 2.0), 74);
      expect(decodePixelsForLogicalSize(65.78, 3.0), 197);
      expect(decodePixelsForLogicalSize(37, 3.0), 111);
    });

    test('handles fractional DPR', () {
      expect(decodePixelsForLogicalSize(100, 2.625), 263);
    });
  });
}
