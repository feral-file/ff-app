import 'dart:async';

import 'package:app/infra/config/remote_app_config.dart';
import 'package:app/infra/config/remote_config_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Initial app config snapshot injected at startup (local-first).
final initialRemoteAppConfigProvider = Provider<RemoteAppConfig>((ref) {
  throw UnimplementedError(
    'Initial RemoteAppConfig must be overridden in ProviderScope.',
  );
});

/// Remote config service injected from startup initialization.
final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  throw UnimplementedError(
    'RemoteConfigService must be overridden in ProviderScope.',
  );
});

/// Runtime source of truth for remote app config.
class RemoteAppConfigNotifier extends Notifier<RemoteAppConfig> {
  late final Logger _log;

  @override
  RemoteAppConfig build() {
    _log = Logger('RemoteAppConfigNotifier');
    return ref.watch(initialRemoteAppConfigProvider);
  }

  Future<bool> refreshInBackground() async {
    try {
      final service = ref.read(remoteConfigServiceProvider);
      final updated = await service.refreshIfChanged();
      if (!ref.mounted) return false;
      if (updated != null) {
        state = updated.config;
        _log.info('Remote config updated from network.');
        return true;
      }
    } on Exception catch (e, stack) {
      if (!ref.mounted) return false;
      _log.warning('Failed to refresh remote config.', e, stack);
    }
    return false;
  }

  void setConfig(RemoteAppConfig config) {
    state = config;
  }
}

final remoteAppConfigProvider =
    NotifierProvider<RemoteAppConfigNotifier, RemoteAppConfig>(
      RemoteAppConfigNotifier.new,
    );

/// Convenience provider for curated channels loaded from remote config.
final curatedChannelUrlsProvider = Provider<List<String>>((ref) {
  return ref.watch(remoteAppConfigProvider).curatedChannelUrls;
});

/// Convenience provider for feed cache duration from remote config.
final remoteFeedCacheDurationProvider = Provider<Duration>((ref) {
  return ref.watch(remoteAppConfigProvider).feedCacheDuration;
});

/// Convenience provider for remote feed last-updated timestamp.
final remoteFeedLastUpdatedAtProvider = Provider<DateTime>((ref) {
  return ref.watch(remoteAppConfigProvider).feedLastUpdatedAt;
});
