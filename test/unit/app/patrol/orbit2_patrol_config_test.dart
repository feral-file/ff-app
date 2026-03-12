import 'package:app/app/patrol/orbit2_patrol_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Orbit2PatrolConfig.fromEnvironment', () {
    test('parses required and optional values', () {
      final config = Orbit2PatrolConfig.fromEnvironment({
        'ORBIT2_FF1_DEVICE_ID': 'device-123',
        'ORBIT2_FF1_TOPIC_ID': 'topic-456',
        'ORBIT2_FF1_NAME': 'Orbit 2',
        'ORBIT2_CANARY_CHANNEL_TITLE': 'Orbit Canary',
        'ORBIT2_CANARY_CHANNEL_ID': 'channel-1',
        'ORBIT2_CANARY_WORK_ID': 'work-1',
        'ORBIT2_SOAK_MINUTES': '240',
      });

      expect(config.ff1DeviceId, 'device-123');
      expect(config.ff1TopicId, 'topic-456');
      expect(config.ff1Name, 'Orbit 2');
      expect(config.canaryChannelId, 'channel-1');
      expect(config.canaryWorkId, 'work-1');
      expect(config.soakDuration, const Duration(minutes: 240));
    });

    test('prefers seconds over minutes for short CI soak runs', () {
      final config = Orbit2PatrolConfig.fromEnvironment({
        'ORBIT2_FF1_DEVICE_ID': 'device-123',
        'ORBIT2_FF1_TOPIC_ID': 'topic-456',
        'ORBIT2_CANARY_CHANNEL_TITLE': 'Orbit Canary',
        'ORBIT2_SOAK_MINUTES': '240',
        'ORBIT2_SOAK_SECONDS': '30',
      });

      expect(config.soakDuration, const Duration(seconds: 30));
    });

    test('throws when required values are missing', () {
      expect(
        () => Orbit2PatrolConfig.fromEnvironment({
          'ORBIT2_FF1_DEVICE_ID': 'device-123',
        }),
        throwsA(isA<StateError>()),
      );
    });
  });
}
