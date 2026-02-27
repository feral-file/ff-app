import 'dart:async';

import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('SeedDownloadNotifier');

/// Possible states of the background seed-database download.
enum SeedDownloadStatus {
  /// Download not yet started.
  idle,

  /// Download is in progress.
  downloading,

  /// Download and placement succeeded.
  done,

  /// Download failed; the app will proceed with an empty database.
  error,
}

/// State for [SeedDownloadNotifier].
class SeedDownloadState {
  /// Creates a [SeedDownloadState].
  const SeedDownloadState({
    required this.status,
    this.errorMessage,
  });

  /// Current download status.
  final SeedDownloadStatus status;

  /// Error message when [status] is [SeedDownloadStatus.error].
  final String? errorMessage;

  /// Returns a copy with the given fields replaced.
  SeedDownloadState copyWith({
    SeedDownloadStatus? status,
    String? errorMessage,
  }) {
    return SeedDownloadState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Orchestrates the one-time background seed-database download.
///
/// The notifier is kicked off early at app startup (see `App` widget).
/// It downloads the seed file in the background without blocking navigation.
/// Progress is logged at every 10 % increment. On completion (success or
/// failure) it opens `SeedDatabaseGate` so the Drift database can proceed.
class SeedDownloadNotifier extends Notifier<SeedDownloadState> {
  @override
  SeedDownloadState build() {
    return const SeedDownloadState(status: SeedDownloadStatus.idle);
  }

  /// Starts the background download.
  ///
  /// No-ops if a download is already in progress or has succeeded.
  Future<void> startDownload() async {
    if (state.status == SeedDownloadStatus.downloading ||
        state.status == SeedDownloadStatus.done) {
      return;
    }

    state = const SeedDownloadState(status: SeedDownloadStatus.downloading);

    final service = ref.read(seedDatabaseServiceProvider);

    // Track progress locally — we log every 10 % but do NOT push intermediate
    // values into Riverpod state. Updating state on every byte chunk floods the
    // provider observer log with thousands of update messages.
    var lastLoggedBucket = -1;

    try {
      await service.downloadAndPlace(
        onProgress: (progress) {
          final bucket = (progress * 10).floor(); // 0–10
          if (bucket > lastLoggedBucket) {
            lastLoggedBucket = bucket;
            final pct = (progress * 100).round();
            _log.info('Seed database download: $pct%');
          }
        },
      );

      _log.info('Seed database download complete');
      state = const SeedDownloadState(status: SeedDownloadStatus.done);
      SeedDatabaseGate.complete();
    } on Exception catch (e, st) {
      _log.severe(
        'Seed database download failed; the app will proceed with an empty '
        'database. Workers will start once the database is open.',
        e,
        st,
      );
      state = SeedDownloadState(
        status: SeedDownloadStatus.error,
        errorMessage: e.toString(),
      );
      // Open the gate even on failure so the Drift DB is not blocked forever.
      SeedDatabaseGate.complete();
    }
  }
}

/// Provider for [SeedDownloadNotifier].
final seedDownloadProvider =
    NotifierProvider<SeedDownloadNotifier, SeedDownloadState>(
      SeedDownloadNotifier.new,
    );

/// Provider for [SeedDatabaseService].
final seedDatabaseServiceProvider = Provider<SeedDatabaseService>((ref) {
  return SeedDatabaseService();
});
