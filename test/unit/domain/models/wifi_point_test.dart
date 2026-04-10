import 'package:app/domain/models/wifi_point.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WifiPoint.fromWifiScanResult', () {
    group('open networks', () {
      test('marks isOpenNetwork true for OPEN security suffix', () {
        final point = WifiPoint.fromWifiScanResult('Cafe|OPEN');
        expect(point.ssid, 'Cafe');
        expect(point.isOpenNetwork, isTrue);
      });

      test('is case-insensitive for OPEN suffix', () {
        expect(
          WifiPoint.fromWifiScanResult('Cafe|open').isOpenNetwork,
          isTrue,
        );
        expect(
          WifiPoint.fromWifiScanResult('Cafe|Open').isOpenNetwork,
          isTrue,
        );
      });

      test('trims whitespace around security token', () {
        final point = WifiPoint.fromWifiScanResult('Cafe| OPEN ');
        expect(point.ssid, 'Cafe');
        expect(point.isOpenNetwork, isTrue);
      });
    });

    group('secured networks', () {
      test('marks isOpenNetwork false for WPA2 suffix', () {
        final point = WifiPoint.fromWifiScanResult('Mars-2026_5G|WPA2');
        expect(point.ssid, 'Mars-2026_5G');
        expect(point.isOpenNetwork, isFalse);
      });

      test('marks isOpenNetwork false for WPA3 suffix', () {
        final point = WifiPoint.fromWifiScanResult('HomeNetwork|WPA3');
        expect(point.ssid, 'HomeNetwork');
        expect(point.isOpenNetwork, isFalse);
      });
    });

    group('plain SSIDs (no security suffix)', () {
      test('returns ssid unchanged and isOpenNetwork false', () {
        final point = WifiPoint.fromWifiScanResult('PlainSSID');
        expect(point.ssid, 'PlainSSID');
        expect(point.isOpenNetwork, isFalse);
      });

      test('handles SSID with spaces', () {
        final point = WifiPoint.fromWifiScanResult('My Home Network');
        expect(point.ssid, 'My Home Network');
        expect(point.isOpenNetwork, isFalse);
      });
    });
  });
}
