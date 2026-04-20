import 'dart:async';

import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/dp1_feed_api_provider.dart';
import 'package:app/app/routing/app_navigator_key.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/services/living_channel_change_detector.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/services/living_channel_polling_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

final _log = Logger('LivingChannelLifecycle');

/// Owns [LivingChannelPollingService] lifecycle (foreground timer + resume poll).
final livingChannelLifecycleProvider =
    NotifierProvider<LivingChannelLifecycleNotifier, void>(
      LivingChannelLifecycleNotifier.new,
    );

/// Coordinates living-channel polling with app foreground/background.
class LivingChannelLifecycleNotifier extends Notifier<void> {
  LivingChannelPollingService? _service;

  @override
  void build() {}

  /// App became active — poll once and restart periodic polling.
  void onAppResumed() {
    final base = _normalizedFeedBase();
    if (base.isEmpty) {
      _log.fine('DP1_FEED_URL unset; living channel polling disabled');
      return;
    }
    final db = ref.read(databaseServiceProvider);
    final api = ref.read(dp1FeedApiProvider);
    _service ??= LivingChannelPollingService(
      api: api,
      databaseService: db,
      feedBaseUrl: base,
      onChanges: _onChanges,
    );
    unawaited(_service!.pollAllFollowed());
    _service!.start();
  }

  /// App backgrounded — stop periodic polling only.
  void onAppPaused() {
    _service?.stop();
  }

  /// Process exit — clear red-dot flags for followed channels.
  Future<void> onAppDetached() async {
    _service?.stop();
    try {
      await ref.read(databaseServiceProvider).clearAllFollowedChannelUpdateIndicators();
    } on Object catch (e, st) {
      _log.warning('clear followed indicators failed', e, st);
    }
  }

  String _normalizedFeedBase() {
    final raw = AppConfig.dp1FeedUrl.trim();
    if (raw.isEmpty) {
      return '';
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  void _onChanges(
    String channelId,
    List<LivingChannelChange> changes,
    String summaryMessage,
    String? playPlaylistId,
  ) {
    final notifier = ref.read(appOverlayProvider.notifier);
    var overlayId = '';
    overlayId = notifier.showToast(
      message: summaryMessage,
      iconPreset: ToastOverlayIconPreset.information,
      autoDismissAfter: const Duration(seconds: 8),
      isTapThroughable: true,
      primaryActionLabel: playPlaylistId != null ? 'Play' : null,
      onPrimaryAction: playPlaylistId == null
          ? null
          : () {
              notifier.dismissOverlay(overlayId);
              final ctx = appNavigatorKey.currentContext;
              if (ctx != null && ctx.mounted) {
                GoRouter.of(ctx).push('${Routes.playlists}/$playPlaylistId');
              }
            },
    );
  }
}
