import 'dart:async';

import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Default item display duration in seconds when none is specified by DP-1.
const int _kDefaultItemDurationSeconds = 60;

/// Playback progress state: the item currently being tracked and its progress.
typedef PlaybackProgressState = ({String? itemId, double progress});

/// Tracks elapsed playback time for the current DP-1 item.
///
/// Resets to 0 whenever the current work index changes. Pauses the internal
/// timer while the player is paused or in sleep mode. Emits progress as a
/// 0.0–1.0 fraction of the item's duration.
final playbackProgressProvider =
    NotifierProvider<PlaybackProgressNotifier, PlaybackProgressState>(
      PlaybackProgressNotifier.new,
    );

/// Notifier for [playbackProgressProvider].
class PlaybackProgressNotifier
    extends Notifier<PlaybackProgressState> {
  Timer? _timer;
  String? _currentItemId;
  int _currentItemDurationSeconds = _kDefaultItemDurationSeconds;
  int _elapsedSeconds = 0;

  @override
  PlaybackProgressState build() {
    ref
      ..onDispose(() => _timer?.cancel())
      ..listen<FF1PlayerStatus?>(
        ff1CurrentPlayerStatusProvider,
        (_, next) => _onStatusChanged(next),
      );
    // Defer initial sync so build() returns first and state is writable.
    unawaited(Future.microtask(() {
      if (!ref.mounted) return;
      _onStatusChanged(ref.read(ff1CurrentPlayerStatusProvider));
    }));
    return (itemId: null, progress: 0.0);
  }

  void _onStatusChanged(FF1PlayerStatus? status) {
    if (status == null ||
        status.items == null ||
        status.currentWorkIndex == null) {
      _reset(null);
      return;
    }

    final index = status.currentWorkIndex!;
    final items = status.items!;
    if (index < 0 || index >= items.length) {
      _reset(null);
      return;
    }

    final item = items[index];
    final newItemId = item.id;
    final duration =
        item.duration > 0 ? item.duration : _kDefaultItemDurationSeconds;

    final shouldPause =
        status.isPaused || (status.sleepMode == true);

    if (newItemId != _currentItemId) {
      _reset(newItemId, duration: duration, startTimer: !shouldPause);
    } else {
      _currentItemDurationSeconds = duration;
      if (shouldPause && _timer != null) {
        _timer!.cancel();
        _timer = null;
      } else if (!shouldPause && _timer == null) {
        _startTimer();
      }
    }
  }

  void _reset(
    String? itemId, {
    int duration = _kDefaultItemDurationSeconds,
    bool startTimer = true,
  }) {
    _timer?.cancel();
    _timer = null;
    _elapsedSeconds = 0;
    _currentItemId = itemId;
    _currentItemDurationSeconds =
        duration > 0 ? duration : _kDefaultItemDurationSeconds;
    state = (itemId: itemId, progress: 0.0);
    if (itemId != null && startTimer) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      final progress =
          (_elapsedSeconds / _currentItemDurationSeconds).clamp(0.0, 1.0);
      state = (itemId: _currentItemId, progress: progress);
    });
  }
}
