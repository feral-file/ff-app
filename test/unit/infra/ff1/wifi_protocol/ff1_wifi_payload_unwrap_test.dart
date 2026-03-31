import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_payload_unwrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('unwrapFf1RelayerPayload', () {
    test('unwraps message then data', () {
      final response = {
        'message': {
          'data': {
            'cpu': {'max_frequency': 100},
          },
        },
      };
      final out = unwrapFf1RelayerPayload(response);
      expect(out['cpu'], isNotNull);
    });

    test('returns leaf map', () {
      final response = {'panels': <dynamic>[]};
      final out = unwrapFf1RelayerPayload(response);
      expect(out['panels'], isEmpty);
    });
  });
}
