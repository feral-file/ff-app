import 'package:app/infra/config/dismissed_firmware_versions_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeDismissedFirmwareVersionsMap', () {
    test('empty string yields empty map', () {
      expect(decodeDismissedFirmwareVersionsMap(''), isEmpty);
    });

    test('valid JSON object yields string map', () {
      expect(
        decodeDismissedFirmwareVersionsMap(
          '{"d1":"1.0.0","d2":"2.0.0"}',
        ),
        <String, String>{'d1': '1.0.0', 'd2': '2.0.0'},
      );
    });

    test('malformed JSON yields empty map', () {
      expect(decodeDismissedFirmwareVersionsMap('not-json'), isEmpty);
    });
  });

  group('encodeDismissedFirmwareVersionsMap', () {
    test('round-trip with decode', () {
      const original = <String, String>{'devA': '1.2.3', 'devB': '4.5.6'};
      final encoded = encodeDismissedFirmwareVersionsMap(original);
      expect(decodeDismissedFirmwareVersionsMap(encoded), original);
    });
  });
}
