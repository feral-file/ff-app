import 'dart:async';

import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// A Riverpod-backed bridge for app lifecycle events.
///
/// This enables non-UI layers (providers/notifiers) to pause/resume background
/// work when the app goes to background/foreground.
///
/// Lifecycle changes are used to coordinate app-level background/foreground work.
class AppLifecycleNotifier extends Notifier<AppLifecycleState> {
  late final Logger _log;
  late final StructuredLogger _slog;
  late final _Observer _observer;

  @override
  AppLifecycleState build() {
    _log = Logger('AppLifecycleNotifier');
    _slog = AppStructuredLog.forLogger(_log, context: {'component': 'app_lifecycle'});
    _observer = _Observer(_onLifecycleChanged);
    WidgetsBinding.instance.addObserver(_observer);

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(_observer);
    });

    final initialState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    if (initialState == AppLifecycleState.resumed) {
      final coordinator = ref.read(tokensSyncCoordinatorProvider.notifier);
      unawaited(coordinator.syncAllTrackedAddresses());
      coordinator.startSyncCollectionPolling();
    }
    return initialState;
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    this.state = state;
    _log.fine('Lifecycle changed: $state');

    final coordinator = ref.read(tokensSyncCoordinatorProvider.notifier);

    if (state == AppLifecycleState.resumed) {
      unawaited(coordinator.syncAllTrackedAddresses());
      coordinator.startSyncCollectionPolling();
      // Reconnect relayer WebSocket when app resumes; Timer-based reconnect
      // does not fire while app is suspended.
      _slog.info(
        category: LogCategory.wifi,
        event: 'lifecycle_resumed',
        message: 'app resumed — triggering relayer reconnect',
      );
      unawaited(
        ref.read(ff1WifiConnectionProvider.notifier).reconnect(),
      );
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      coordinator.pauseSyncCollectionPolling();
      // Pause relayer WebSocket to free resources; reconnect on resume.
      // Note: `inactive` fires frequently on iOS (notification shade, control
      // centre) so it also triggers pause/resume cycles — tracked as
      // lifecycle_paused events to help diagnose false "Device not connected".
      _slog.info(
        category: LogCategory.wifi,
        event: 'lifecycle_paused',
        message: 'app lifecycle: $state — pausing relayer connection',
        payload: {'lifecycleState': state.name},
      );
      ref.read(ff1WifiConnectionProvider.notifier).pauseConnection();
    }
  }
}

class _Observer with WidgetsBindingObserver {
  _Observer(this.onChanged);

  final void Function(AppLifecycleState state) onChanged;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    onChanged(state);
  }
}

/// Provider for current app lifecycle state.
final appLifecycleProvider =
    NotifierProvider<AppLifecycleNotifier, AppLifecycleState>(
      AppLifecycleNotifier.new,
    );
