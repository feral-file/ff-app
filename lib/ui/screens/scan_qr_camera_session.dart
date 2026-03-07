import 'dart:async';

/// Serializes camera start/stop requests for [ScanQrPage].
///
/// Mobile lifecycle and route callbacks can emit rapid, duplicated resume/pause
/// events. This helper ensures camera transitions run in order and only when the
/// desired state actually changes.
class ScanQrCameraSession {
  /// Creates a session coordinator around camera callbacks.
  ScanQrCameraSession({
    required Future<void> Function() startCamera,
    required Future<void> Function() stopCamera,
  }) : _startCamera = startCamera,
       _stopCamera = stopCamera;

  final Future<void> Function() _startCamera;
  final Future<void> Function() _stopCamera;

  bool _isRunning = false;
  bool _shouldRun = false;
  bool _isDisposed = false;
  Future<void> _queue = Future<void>.value();

  /// Requests camera start.
  Future<void> resume() {
    _shouldRun = true;
    return _enqueueStateTransition();
  }

  /// Requests camera stop.
  Future<void> pause() {
    _shouldRun = false;
    return _enqueueStateTransition();
  }

  /// Releases the coordinator and waits for queued work to complete.
  Future<void> dispose() async {
    _isDisposed = true;
    await _queue;
  }

  Future<void> _enqueueStateTransition() {
    final transition = _queue.then((_) async {
      if (_isDisposed || _isRunning == _shouldRun) {
        return;
      }

      if (_shouldRun) {
        await _startCamera();
        _isRunning = true;
        return;
      }

      await _stopCamera();
      _isRunning = false;
    });

    _queue = transition.catchError((_) {
      // Keep the queue alive for later transitions if a camera call fails.
    });

    return transition;
  }
}
