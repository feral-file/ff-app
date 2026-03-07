import 'dart:async';

import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
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
  late final _Observer _observer;

  @override
  AppLifecycleState build() {
    _log = Logger('AppLifecycleNotifier');
    _observer = _Observer(_onLifecycleChanged);
    WidgetsBinding.instance.addObserver(_observer);

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(_observer);
    });

    final initialState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    if (initialState == AppLifecycleState.resumed) {
      unawaited(
        ref
            .read(tokensSyncCoordinatorProvider.notifier)
            .syncAllTrackedAddresses(),
      );
    }
    return initialState;
  }

  void _onLifecycleChanged(AppLifecycleState state) {
    this.state = state;
    _log.fine('Lifecycle changed: $state');

    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref
            .read(tokensSyncCoordinatorProvider.notifier)
            .syncAllTrackedAddresses(),
      );
      // Reconnect relayer WebSocket when app resumes; Timer-based reconnect
      // does not fire while app is suspended.
      unawaited(
        ref.read(ff1WifiConnectionProvider.notifier).reconnect(),
      );
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
