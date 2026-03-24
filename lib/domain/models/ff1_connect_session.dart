import 'dart:async';

/// Terminal outcome of an FF1 connect attempt.
enum FF1ConnectOutcome {
  /// Device connected with portal already set; ready for device config.
  portalReady,

  /// Device connected but needs Wi-Fi setup; route to scan networks.
  needsWiFi,

  /// Device connected; Wi-Fi setup complete; ready for device config.
  wiFiReady,

  /// Device pairing failed (BLE, version, or other); terminal error.
  failed,

  /// User cancelled the attempt.
  cancelled,
}

/// Session object that owns the lifecycle of a single FF1 connect attempt.
///
/// Each session tracks:
/// - Unique ID (auto-incremented per app process)
/// - Cancellation state and cancellation token
/// - Timer scheduling (for "still connecting", timeouts, etc.)
/// - Bluetooth readiness wait state
/// - Terminal outcome
///
/// Sessions are single-use and immutable after completion.
class FF1ConnectSession {
  /// Constructor (typically called by FF1ConnectSessionFactory).
  FF1ConnectSession(this._id);

  final int _id;
  bool _cancelled = false;
  Timer? _timer;
  Completer<void>? _btReadyCompleter;
  FF1ConnectOutcome? _outcome;

  /// Unique session ID within this app process.
  int get id => _id;

  /// Whether this session has been cancelled by user/caller.
  bool get isCancelled => _cancelled;

  /// Terminal outcome; null until explicitly set via completeWithOutcome().
  FF1ConnectOutcome? get outcome => _outcome;

  /// Whether this session has reached a terminal state (outcome != null).
  bool get isTerminal => _outcome != null;

  /// Schedule a one-shot timer (cancels any previous timer).
  ///
  /// Used for "still connecting" delays, timeouts, etc.
  /// Automatically cancelled if session is cancelled before elapsed time.
  void scheduleTimer(Duration delay, void Function() onElapsed) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      if (!_cancelled) {
        onElapsed();
      }
    });
  }

  /// Cancel this session (unblocks waiting operations, sets isCancelled).
  ///
  /// If [_btReadyCompleter] is waiting, completes it with error.
  /// Idempotent: safe to call multiple times.
  void cancel() {
    _cancelled = true;
    _timer?.cancel();
    if (!(_btReadyCompleter?.isCompleted ?? true)) {
      _btReadyCompleter?.completeError(
        const _FF1SessionCancelledError(),
      );
    }
  }

  /// Mark session as complete with a terminal outcome.
  ///
  /// Once outcome is set, the session cannot be re-entered.
  /// Should only be called once per session.
  void completeWithOutcome(FF1ConnectOutcome outcome) {
    _outcome = outcome;
    _timer?.cancel();
  }

  /// Register a completer for "wait until Bluetooth adapter is on" flow.
  ///
  /// The completer is stored so that cancel() can unblock it.
  /// Internal use only (by providers that need BT readiness).
  Completer<void>? get btReadyCompleter => _btReadyCompleter;
  set btReadyCompleter(Completer<void> completer) {
    _btReadyCompleter = completer;
  }
}

/// Internal error used to signal session cancellation to waiting futures.
class _FF1SessionCancelledError implements Exception {
  const _FF1SessionCancelledError();

  @override
  String toString() => 'FF1 session cancelled';
}

/// Factory for creating new FF1 connect sessions with auto-incrementing IDs.
class FF1ConnectSessionFactory {
  int _sessionCounter = 0;

  /// Create a new session with a unique ID.
  FF1ConnectSession createSession() {
    return FF1ConnectSession(++_sessionCounter);
  }
}
