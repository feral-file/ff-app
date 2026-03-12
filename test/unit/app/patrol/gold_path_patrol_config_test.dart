import 'package:app/app/patrol/gold_path_patrol_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GoldPathPatrolConfig.fromEnvironment', () {
    test('parses required and optional values', () {
      final config = GoldPathPatrolConfig.fromEnvironment({
        'FF1_DEVICE_ID': 'device-123',
        'FF1_TOPIC_ID': 'topic-456',
        'GOLD_PATH_FF1_NAME': 'Patrol Test FF1',
        'GOLD_PATH_CANARY_CHANNEL_TITLE': 'Canary',
        'GOLD_PATH_CANARY_CHANNEL_ID': 'channel-1',
        'GOLD_PATH_CANARY_WORK_ID': 'work-1',
        'GOLD_PATH_SOAK_MINUTES': '240',
      });

      expect(config.ff1DeviceId, 'device-123');
      expect(config.ff1TopicId, 'topic-456');
      expect(config.ff1Name, 'Patrol Test FF1');
      expect(config.canaryChannelId, 'channel-1');
      expect(config.canaryWorkId, 'work-1');
      expect(config.soakDuration, const Duration(minutes: 240));
    });

    test('prefers seconds over minutes for short CI soak runs', () {
      final config = GoldPathPatrolConfig.fromEnvironment({
        'FF1_DEVICE_ID': 'device-123',
        'FF1_TOPIC_ID': 'topic-456',
        'GOLD_PATH_CANARY_CHANNEL_TITLE': 'Canary',
        'GOLD_PATH_SOAK_MINUTES': '240',
        'GOLD_PATH_SOAK_SECONDS': '30',
      });

      expect(config.soakDuration, const Duration(seconds: 30));
    });

    test('throws when required values are missing', () {
      expect(
        () => GoldPathPatrolConfig.fromEnvironment({
          'FF1_DEVICE_ID': 'device-123',
        }),
        throwsA(isA<StateError>()),
      );
    });
  });
}
