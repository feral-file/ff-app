import 'package:app/infra/ff1/wifi_protocol/ff1_device_status_pairing_qr.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FF1DeviceStatusPairingQr.isPairingQrShowing', () {
    test('returns null when displayUrl is absent', () {
      const status = FF1DeviceStatus();
      expect(status.isPairingQrShowing, isNull);
    });

    test('returns null when displayUrl is empty string in model', () {
      // fromJson normalizes empty to null; direct const cannot set empty.
      final status = FF1DeviceStatus.fromJson({'displayURL': '   '});
      expect(status.displayUrl, isNull);
      expect(status.isPairingQrShowing, isNull);
    });

    test('returns true when displayUrl indicates qr step', () {
      const status = FF1DeviceStatus(
        displayUrl: 'https://example.com/?step=qrcode',
      );
      expect(status.isPairingQrShowing, isTrue);
    });

    test('returns false when displayUrl step has no qr', () {
      const status = FF1DeviceStatus(
        displayUrl: 'https://example.com/?step=home',
      );
      expect(status.isPairingQrShowing, isFalse);
    });
  });
}
