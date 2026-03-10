import 'package:app/infra/logging/log_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogSanitizer', () {
    test('redacts sensitive fields in nested maps', () {
      final sanitized = LogSanitizer.sanitizeMap({
        'Authorization': 'Bearer secret-token',
        'nested': {
          'password': '123456',
          'safe': 'value',
        },
        'api_key': 'abc',
      });

      expect(sanitized['Authorization'], 'REDACTED');
      final nested = sanitized['nested'] as Map<String, dynamic>;
      expect(nested['password'], 'REDACTED');
      expect(nested['safe'], 'value');
      expect(sanitized['api_key'], 'REDACTED');
    });

    test('summarizes BLE payload safely', () {
      final bytes = List<int>.generate(20, (index) => index);
      final result = LogSanitizer.sanitizeBlePayload(bytes, maxPreviewBytes: 8);

      expect(result['length'], 20);
      expect(result['hexPreview'], '00 01 02 03 04 05 06 07');
      expect(result['truncated'], isTrue);
    });

    test('summarizes list body without dumping full payload', () {
      final sanitized = LogSanitizer.sanitizeBody(List<int>.filled(50, 1));

      expect(sanitized, {
        'type': 'list',
        'length': 50,
      });
    });
  });
}
