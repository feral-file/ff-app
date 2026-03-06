import 'dart:async';

import 'package:app/infra/config/seed_database_config_store.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('SeedDownloadNotifier');

/// Possible states of the background seed-database download.
enum SeedDownloadStatus {
  /// Download not yet started.
  idle,

  /// Sync is in progress.
  syncing,

  /// Sync finished (download may have been skipped when ETag unchanged).
  done,

  /// Sync failed; app start may continue with existing DB or empty DB.
  error,
}

/// State for [SeedDownloadNotifier].
class SeedDownloadState {
  /// Creates a [SeedDownloadState].
  const SeedDownloadState({
    required this.status,
    this.errorMessage,
    this.progress,
  });

  /// Current download status.
  final SeedDownloadStatus status;

  /// Error message when [status] is [SeedDownloadStatus.error].
  final String? errorMessage;

  /// Download progress 0.0–1.0 when [status] is [SeedDownloadStatus.syncing].
  final double? progress;

  /// Returns a copy with the given fields replaced.
  SeedDownloadState copyWith({
    SeedDownloadStatus? status,
    String? errorMessage,
    double? progress,
  }) {
    return SeedDownloadState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}

/// Orchestrates the one-time background seed-database download.
///
/// The notifier is kicked off early at app startup (see `App` widget), where
/// it can perform an ETag-based refresh. On completion (success/failure/skip)
/// it opens `SeedDatabaseGate` so Drift can proceed.
class SeedDownloadNotifier extends Notifier<SeedDownloadState> {
  @override
  SeedDownloadState build() {
    return const SeedDownloadState(status: SeedDownloadStatus.idle);
  }

  /// Syncs seed DB at app start using remote ETag comparison.
  ///
  /// No-ops if a sync is already in progress.
  ///
  /// This method may be called again after startup (for example, when the app
  /// resumes from background) to check for a newer remote snapshot.
  Future<bool> syncAtAppStart({
    required Future<void> Function() beforeReplace,
    required Future<void> Function() afterReplace,
    bool failSilently = true,
  }) async {
    if (state.status == SeedDownloadStatus.syncing) {
      return false;
    }

    state = const SeedDownloadState(
      status: SeedDownloadStatus.syncing,
      progress: 0,
    );

    final service = ref.read(seedDatabaseSyncServiceProvider);

    // Throttle state updates to every 1% to avoid flooding provider observer.
    var lastProgressBucket = -1;

    try {
      final updated = await service.syncIfNeeded(
        beforeReplace: beforeReplace,
        afterReplace: afterReplace,
        failSilently: failSilently,
        onProgress: (progress) {
          final bucket = (progress * 100).floor();
          if (bucket > lastProgressBucket) {
            lastProgressBucket = bucket;
            _log.info(
              'Seed database sync download: ${(progress * 100).round()}%',
            );
            state = state.copyWith(progress: progress);
          }
        },
      );

      _log.info('Seed database sync complete');
      state = const SeedDownloadState(status: SeedDownloadStatus.done);
      SeedDatabaseGate.complete();
      return updated;
    } on Exception catch (e, st) {
      _log.severe(
        'Seed database sync failed; app continues with existing database.',
        e,
        st,
      );
      state = SeedDownloadState(
        status: SeedDownloadStatus.error,
        errorMessage: e.toString(),
      );
      // Open the gate even on failure so the Drift DB is not blocked forever.
      SeedDatabaseGate.complete();
      return false;
    }
  }
}

/// Provider for [SeedDownloadNotifier].
final seedDownloadProvider =
    NotifierProvider<SeedDownloadNotifier, SeedDownloadState>(
      SeedDownloadNotifier.new,
    );

/// Provider for retrying seed download. Must be overridden by the app
/// bootstrap with the actual sync logic.
final seedDownloadRetryProvider = Provider<Future<void> Function()>((ref) {
  throw UnimplementedError(
    'seedDownloadRetryProvider must be overridden by the app',
  );
});

/// Provider for [SeedDatabaseService].
final seedDatabaseServiceProvider = Provider<SeedDatabaseService>((ref) {
  return SeedDatabaseService();
});

/// Provider for ObjectBox-backed seed DB config metadata storage.
final seedDatabaseConfigStoreProvider = Provider<SeedDatabaseConfigStore>((
  ref,
) {
  final store = getInitializedObjectBoxStore();
  final box = store.box<RemoteAppConfigEntity>();
  return SeedDatabaseConfigStore(box);
});

/// Provider for ETag-based seed DB sync orchestration.
final seedDatabaseSyncServiceProvider = Provider<SeedDatabaseSyncService>((
  ref,
) {
  final configStore = ref.read(seedDatabaseConfigStoreProvider);
  return SeedDatabaseSyncService(
    seedDatabaseService: ref.read(seedDatabaseServiceProvider),
    loadLocalEtag: configStore.loadSeedEtag,
    saveLocalEtag: configStore.saveSeedEtag,
  );
});
