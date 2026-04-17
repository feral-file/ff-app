import 'package:app/domain/ff1/ff1_pairing_qr_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isPairingQrStepInDisplayUrl', () {
    test('returns true when step contains qr (e.g. qrcode)', () {
      expect(
        isPairingQrStepInDisplayUrl(
          'https://example.com/path?foo=1&step=qrcode',
        ),
        isTrue,
      );
    });

    test('returns true when step contains qr in another form', () {
      expect(
        isPairingQrStepInDisplayUrl(
          'https://example.com/?step=pairingQr',
        ),
        isTrue,
      );
    });

    test('returns false when step is missing or has no qr substring', () {
      expect(
        isPairingQrStepInDisplayUrl('https://example.com/'),
        isFalse,
      );
      expect(
        isPairingQrStepInDisplayUrl('https://example.com/?step=other'),
        isFalse,
      );
    });

    test('returns true when step in fragment query contains qr', () {
      expect(
        isPairingQrStepInDisplayUrl(
          'http://127.0.0.1:9222/#/setup?step=qrcode',
        ),
        isTrue,
      );
    });

    test('returns false for unparseable url', () {
      expect(isPairingQrStepInDisplayUrl('::'), isFalse);
    });
  });
}
