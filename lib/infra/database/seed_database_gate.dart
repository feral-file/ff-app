import 'dart:async';

/// Gate that prevents the Drift database from opening until the seed file is
/// on disk or the user has an existing library file from a prior run.
///
/// On a fresh install the seed database is downloaded in the background.
/// The app database open path awaits [future] before opening; [complete] is
/// only called when `dp1_library.sqlite` exists (after seed download notifier).
/// If the first download fails, the gate stays pending — the app must not open
/// Drift without a seed file.
///
/// Returning users already have the file: bootstrap calls [complete] at launch
/// when the file exists, so there is zero wait on subsequent runs.
class SeedDatabaseGate {
  SeedDatabaseGate._();

  static var _completer = Completer<void>();

  /// Whether the gate has already been opened.
  static bool get isCompleted => _completer.isCompleted;

  /// Completes the gate, unblocking any pending [future] awaiters.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops.
  static void complete() {
    if (_completer.isCompleted) return;
    _completer.complete();
  }

  /// A [Future] that resolves once [complete] is called.
  ///
  /// Resolves immediately (next microtask) if the gate has already been opened.
  static Future<void> get future => _completer.future;

  /// Resets the gate to its initial locked state.
  ///
  /// For use in tests only.
  static void resetForTesting() {
    _completer = Completer<void>();
  }
}
