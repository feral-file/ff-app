import 'package:app/util/json_string_map_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('decodeJsonStringMap', () {
    test('empty string yields empty map', () {
      expect(decodeJsonStringMap(''), isEmpty);
    });

    test('valid JSON object yields string map', () {
      expect(
        decodeJsonStringMap('{"a":"1","b":"2"}'),
        {'a': '1', 'b': '2'},
      );
    });

    test('invalid JSON yields empty map', () {
      expect(decodeJsonStringMap('not-json'), isEmpty);
    });
  });

  group('encodeJsonStringMap', () {
    test('round-trip preserves entries', () {
      const original = {'device-1': '1.0.0', 'device-2': '2.0.0'};
      final encoded = encodeJsonStringMap(original);
      expect(decodeJsonStringMap(encoded), original);
    });
  });
}
