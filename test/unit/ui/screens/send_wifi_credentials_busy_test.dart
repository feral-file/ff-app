import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/ui/screens/send_wifi_credentials_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isWifiPasswordSubmitBusy', () {
    test('returns false when status is error even if local flag is true', () {
      expect(
        isWifiPasswordSubmitBusy(
          localProcessingFlag: true,
          status: WiFiConnectionStatus.error,
        ),
        isFalse,
      );
    });

    test('returns true when local flag is true and status is selectingNetwork', () {
      expect(
        isWifiPasswordSubmitBusy(
          localProcessingFlag: true,
          status: WiFiConnectionStatus.selectingNetwork,
        ),
        isTrue,
      );
    });

    test('returns true for sendingCredentials without local flag', () {
      expect(
        isWifiPasswordSubmitBusy(
          localProcessingFlag: false,
          status: WiFiConnectionStatus.sendingCredentials,
        ),
        isTrue,
      );
    });

    test('returns false for idle without local flag', () {
      expect(
        isWifiPasswordSubmitBusy(
          localProcessingFlag: false,
          status: WiFiConnectionStatus.idle,
        ),
        isFalse,
      );
    });
  });
}
