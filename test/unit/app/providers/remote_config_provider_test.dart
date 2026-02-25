import 'package:app/app/providers/remote_config_provider.dart';
import 'package:app/infra/config/remote_app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test('remote config convenience providers expose expected slices', () {
    // Unit test: verifies convenience providers derive values from remote config state.
    final config = RemoteAppConfig(
      publishers: [
        RemoteConfigPublisher(
          id: 0,
          name: 'Feral File',
          channelUrls: const ['https://example.com/channel.json'],
          feedCacheDuration: const Duration(hours: 6),
          feedLastUpdatedAt: DateTime.utc(2025),
        ),
      ],
    );
    final container = ProviderContainer.test(
      overrides: [
        initialRemoteAppConfigProvider.overrideWithValue(config),
        remoteConfigServiceProvider.overrideWithValue(
          MockRemoteConfigService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(curatedChannelUrlsProvider), hasLength(1));
    expect(
      container.read(remoteConfigPublishersProvider).single.name,
      'Feral File',
    );
    expect(
      container.read(remoteFeedCacheDurationProvider),
      const Duration(hours: 6),
    );
    expect(
      container.read(remoteFeedLastUpdatedAtProvider),
      DateTime.utc(2025),
    );
  });
}
