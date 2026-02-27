import 'dart:async';

/// Gate that prevents the Drift database from opening until the seed file is
/// placed on disk (or the download has definitively failed/been skipped).
///
/// On a fresh install the seed database is downloaded in the background while
/// the user goes through onboarding. `AppDatabase._openConnection` awaits
/// `SeedDatabaseGate.future` before the `LazyDatabase` opens, so the first
/// DB access either finds the seed file or — if download failed — creates a
/// fresh empty database rather than racing with an in-progress download.
///
/// Returning users already have the file: `main` calls [complete] at launch
/// so there is zero wait on subsequent runs.
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
