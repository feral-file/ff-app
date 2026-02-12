import 'package:app/infra/config/remote_app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RemoteAppConfig', () {
    test('parses publisher array and assigns index-based ids', () {
      final config = RemoteAppConfig.fromJson({
        'dp1_playlist': {
          'publishers': [
            {
              'name': 'Feral File',
              'channel_urls': [
                'https://a.example/api/v1/channels/ch_1',
              ],
              'feed_cache_duration': '604800',
              'feed_last_updated': '2026-02-02T03:00:00.0Z',
            },
            {
              'name': 'Objkt',
              'channel_urls': [
                'https://b.example/api/v1/channels/ch_2',
              ],
              'feed_cache_duration': '86400',
              'feed_last_updated': '2026-02-03T03:00:00.0Z',
            },
          ],
        },
      });

      expect(config.publishers, hasLength(2));
      expect(config.publishers[0].id, equals(0));
      expect(config.publishers[0].name, equals('Feral File'));
      expect(config.publishers[1].id, equals(1));
      expect(config.publishers[1].name, equals('Objkt'));
      expect(config.curatedChannelUrls, hasLength(2));
      expect(config.feedCacheDuration, const Duration(days: 1));
      expect(
        config.feedLastUpdatedAt,
        DateTime.parse('2026-02-03T03:00:00.0Z').toUtc(),
      );
    });

    test('throws when publishers are missing', () {
      expect(
        () => RemoteAppConfig.fromJson({
          'dp1_playlist': {
            'channel_urls': [
              'https://a.example/api/v1/channels/ch_1',
            ],
          },
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
