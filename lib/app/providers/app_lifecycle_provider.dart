import 'dart:async';

import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// A Riverpod-backed bridge for app lifecycle events.
///
/// This enables non-UI layers (providers/notifiers) to pause/resume background
/// work when the app goes to background/foreground.
///
/// When the app transitions to background (paused/inactive/detached), this
/// notifier triggers a WAL checkpoint to ensure all in-flight data is written
/// to disk. This is the single durability point for all database operations.
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

    // Checkpoint database when app goes to background to ensure durability.
    // This is the single point where we persist all WAL changes to disk,
    // replacing expensive per-operation checkpoints.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_checkpointDatabase());
    } else if (state == AppLifecycleState.resumed) {
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

  Future<void> _checkpointDatabase() async {
    try {
      final databaseService = ref.read(databaseServiceProvider);
      await databaseService.checkpoint();
      _log.info('Database checkpoint completed on app background');
    } on Exception catch (e) {
      _log.warning('Failed to checkpoint database: $e');
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
