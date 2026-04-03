import 'package:app/infra/ff1/wifi_control/ff1_wifi_control_verifier.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ff1CommandResponseIsOk', () {
    test('returns true when status is ok (case-insensitive)', () {
      final response = FF1CommandResponse(status: 'OK');

      expect(ff1CommandResponseIsOk(response), isTrue);
    });

    test('returns false for non-ok status', () {
      final response = FF1CommandResponse(status: 'error');

      expect(ff1CommandResponseIsOk(response), isFalse);
    });
  });

  group('ff1CommandResponseSucceeded', () {
    test('prefers explicit ok=false over status ok', () {
      final response = FF1CommandResponse(
        status: 'ok',
        data: <String, dynamic>{'ok': false},
      );

      expect(ff1CommandResponseSucceeded(response), isFalse);
    });

    test('falls back to status when ok flag is absent', () {
      final response = FF1CommandResponse(status: 'ok');

      expect(ff1CommandResponseSucceeded(response), isTrue);
    });
  });

  group('ff1DeviceStatusHasSignal', () {
    test('returns true when wifi name exists', () {
      const status = FF1DeviceStatus(connectedWifi: 'Studio-Wifi');

      expect(ff1DeviceStatusHasSignal(status), isTrue);
    });

    test('returns true when internetConnected exists', () {
      const status = FF1DeviceStatus(internetConnected: true);

      expect(ff1DeviceStatusHasSignal(status), isTrue);
    });

    test('returns false when status has no signal fields', () {
      const status = FF1DeviceStatus();

      expect(ff1DeviceStatusHasSignal(status), isFalse);
    });
  });

  group('ff1CommandResponseOkFlag', () {
    test('returns true from direct ok payload', () {
      final response = FF1CommandResponse(
        data: <String, dynamic>{'ok': true},
      );

      expect(ff1CommandResponseOkFlag(response), isTrue);
      expect(ff1CommandResponseHasOkFlag(response), isTrue);
    });

    test('returns false from nested message ok payload', () {
      final response = FF1CommandResponse(
        data: <String, dynamic>{
          'message': <String, dynamic>{'ok': false},
        },
      );

      expect(ff1CommandResponseOkFlag(response), isFalse);
      expect(ff1CommandResponseHasOkFlag(response), isTrue);
    });

    test('returns null when response has no ok field', () {
      final response = FF1CommandResponse(
        data: <String, dynamic>{'orientation': 'landscape'},
      );

      expect(ff1CommandResponseOkFlag(response), isNull);
      expect(ff1CommandResponseHasOkFlag(response), isFalse);
    });
  });

  group('firmware update WiFi success (shared rule)', () {
    test('ambiguous WiFi payload without ok is not WiFi success', () {
      final response = FF1CommandResponse(
        data: <String, dynamic>{'unexpected': true},
      );

      final okFlag = ff1CommandResponseOkFlag(response);
      final success = okFlag ?? ff1CommandResponseIsOk(response);

      expect(success, isFalse);
    });
  });
}
