import 'dart:async';

import 'package:app/app/providers/addresses_provider.dart';
import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/channel_detail_provider.dart';
import 'package:app/app/providers/channel_preview_provider.dart';
import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/me_section_playlists_provider.dart';
import 'package:app/app/providers/playlist_details_provider.dart';
import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/providers/works_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_local_data_cleaner.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/legacy_storage_locator.dart';
import 'package:app/infra/services/local_data_cleanup_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

// ignore_for_file: cascade_invocations // Reason: provider wiring uses concise imperative call order for cleanup flow.

/// Wires [LocalDataCleanupService] for two flows:
///
/// 1. **forgetIExist** (Forget I Exist): full reset → deletes SQLite,
///    ObjectBox, legacy files, then replaces DB from seed and bootstraps.
/// 2. **rebuildMetadata**: preserves favorites and tracked addresses,
///    replaces SQLite from seed, ensures tracked addresses resume indexing.

/// Provider for ObjectBox local data cleanup.
final objectBoxLocalDataCleanerProvider = Provider<ObjectBoxLocalDataCleaner>((
  ref,
) {
  final store = getInitializedObjectBoxStore();
  return ObjectBoxLocalDataCleaner(store);
});

/// Provider for local data cleanup and metadata rebuild flows.
final localDataCleanupServiceProvider = Provider<LocalDataCleanupService>((
  ref,
) {
  final r = ref;

  /// Invalidates DB-facing providers before close/rebind.
  ///
  /// [databaseServiceProvider] invalidation alone is not enough: long-lived
  /// stream/notifier providers that used [ref.read] would not rebuild (Riverpod
  /// only tracks [ref.watch] dependencies). This explicit list plus
  /// [databaseServiceProvider] keeps reset deterministic.
  void invalidateDatabaseConsumerProviders() {
    r.invalidate(databaseServiceProvider);
    r.invalidate(trackedAddressesSyncProvider);
    r.invalidate(addressesProvider);
    r.invalidate(channelDetailsProvider);
    r.invalidate(channelPlaylistsFromIdsProvider);
    r.invalidate(channelPreviewProvider);
    r.invalidate(channelsProvider(ChannelType.dp1));
    r.invalidate(channelsProvider(ChannelType.localVirtual));
    r.invalidate(playlistsProvider(PlaylistType.dp1));
    r.invalidate(playlistsProvider(PlaylistType.addressBased));
    r.invalidate(playlistsProvider(PlaylistType.favorite));
    r.invalidate(meSectionPlaylistsProvider);
    r.invalidate(isWorkInFavoriteProvider);
    r.invalidate(playlistDetailsProvider);
    r.invalidate(worksProvider);
    r.invalidate(workDetailStateProvider);
    r.invalidate(favoritePlaylistServiceProvider);
  }

  /// Invalidates providers that hold the database connection
  /// (appDatabase, databaseService, sync coordinators) so they reconnect.
  void invalidateDatabaseConnectionProviders() {
    r.invalidate(tokensSyncCoordinatorProvider);
    r.invalidate(ensureTrackedAddressesSyncCoordinatorProvider);
    r.invalidate(appDatabaseProvider);
    r.invalidate(databaseServiceProvider);
  }

  /// Downloads seed from S3 (or cache), replaces local dp1_library.sqlite,
  /// then rebinds providers.
  ///
  /// Uses unified [SeedDownloadNotifier.sync] with [setNotReady]/[setReady].
  /// Updates [seedDownloadProvider] so Home tabs show loading during download.
  Future<void> forceReplaceDatabaseFromSeed() async {
    final log = Logger('LocalDataCleanupProvider');
    final seedNotifier = ref.read(seedDownloadProvider.notifier);
    seedNotifier.notifyForceReplaceStarted();

    var lastLoggedPct = -1;
    try {
      final success = await seedNotifier.sync(
        forceReplace: true,
        showLoadingInUI: false,
        completeSeedDatabaseGate: false,
        failSilently: false,
        onProgress: (progress) {
          seedNotifier.notifyForceReplaceProgress(progress);
          final pct = (progress * 100).round();
          if (pct >= lastLoggedPct + 1 || pct >= 100) {
            lastLoggedPct = pct;
            log.info('Seed database download progress: $pct%');
          }
        },
      );
      if (!success) {
        seedNotifier.notifyForceReplaceFinished(
          success: false,
          errorMessage: 'Sync skipped (session overridden or failed)',
        );
        throw StateError(
          'Seed database replace was skipped. Retry will be attempted.',
        );
      }
      await ref
          .read(appStateServiceProvider)
          .setHasCompletedSeedDownload(
            completed: true,
          );
      seedNotifier.notifyForceReplaceFinished();
    } on Object catch (e, st) {
      log.warning('Seed database force replace failed', e, st);
      seedNotifier.notifyForceReplaceFinished(
        success: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  return LocalDataCleanupService(
    /// Set immediately at start of forgetIExist so no new DB work starts.
    prepareForReset: () {
      ref.read(isSeedDatabaseReadyProvider.notifier).setStateDirectly(false);
    },

    /// Called when forgetIExist/rebuildMetadata background seed replace fails.
    /// Invokes [retry] (full sequence: replace + bootstrap + restore for
    /// rebuildMetadata). On retry failure, restores DB-ready so the
    /// app can recover (e.g. show retry UI) instead of staying not-ready forever.
    onResetFailed: (retry) {
      unawaited(
        (() async {
          try {
            await retry();
          } on Object catch (_) {
            // Retry failed; restore readiness so app can recover.
            ref
                .read(isSeedDatabaseReadyProvider.notifier)
                .setStateDirectly(true);
            r.invalidate(appDatabaseProvider);
            r.invalidate(databaseServiceProvider);
          }
        })(),
      );
    },

    /// Calls [SeedDatabaseReadyNotifier.setNotReady] so [onNotReady] runs
    /// (drain workers, invalidate, close SQLite, ObjectBox light clear), then
    /// deletes dp1 sqlite files. If [SeedDatabaseGate] is not completed,
    /// [setNotReady] is a no-op; we mirror drain + close so Forget/rebuild stay
    /// safe on edge boots.
    closeAndDeleteDatabase: () async {
      final readyNotifier = ref.read(isSeedDatabaseReadyProvider.notifier);
      await readyNotifier.setNotReady();
      if (SeedDatabaseGate.isCompleted) {
        final seedDatabaseService = ref.read(seedDatabaseServiceProvider);
        await seedDatabaseService.deleteDatabaseFiles();
      } else {
        await ref
            .read(tokensSyncCoordinatorProvider.notifier)
            .stopAndDrainForReset();
        await ref
            .read(ensureTrackedAddressesSyncCoordinatorProvider.notifier)
            .stopAndDrainForReset();
        r.invalidate(tokensSyncCoordinatorProvider);
        r.invalidate(ensureTrackedAddressesSyncCoordinatorProvider);
        readyNotifier.setStateDirectly(false);
        invalidateDatabaseConsumerProviders();
        await SchedulerBinding.instance.endOfFrame;
        await ref.read(appDatabaseProvider).close();
        final seedDatabaseService = ref.read(seedDatabaseServiceProvider);
        await seedDatabaseService.deleteDatabaseFiles();
        await ref.read(objectBoxLocalDataCleanerProvider).lightClear();
      }
    },

    /// Clears FF1 devices, app state, tracked addresses, etc.
    clearObjectBoxData: () async {
      await ref.read(objectBoxLocalDataCleanerProvider).clearAll();
    },

    /// Clears CachedNetworkImage and Flutter image cache.
    clearCachedImages: () async {
      await CachedNetworkImageProvider.defaultCacheManager.emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    },

    /// Snapshot of Favorite playlists for restore (rebuildMetadata only).
    getFavoritePlaylistsSnapshot: () async {
      final databaseService = ref.read(databaseServiceProvider);
      return databaseService.getFavoritePlaylistsSnapshot();
    },

    /// Restores Favorite playlists from snapshot (rebuildMetadata only).
    restoreFavoritePlaylists: (snapshots) async {
      final databaseService = ref.read(databaseServiceProvider);
      await databaseService.restoreFavoritePlaylistsSnapshot(snapshots);
    },

    /// Creates My Collection channel and wires FF1 watcher.
    runBootstrap: () async {
      await ref.read(bootstrapProvider.notifier).bootstrap();
    },

    /// Replaces SQLite with seed. Used by both forgetIExist and rebuildMetadata.
    recreateDatabaseFromSeed: () async {
      await forceReplaceDatabaseFromSeed();
    },
    pauseFeedWork: () {
      // No-op: feed manager removed; seed database is the source of DP1 data.
    },
    pauseTokenPolling: () {
      ref.read(tokensSyncCoordinatorProvider.notifier).pausePolling();
    },

    /// Deletes playlist_cache.sqlite (legacy). Prevents migration from
    /// re-importing addresses after Forget I Exist.
    clearLegacySqlite: () async {
      await LegacyStorageLocator().deleteLegacySqlite();
    },

    /// Deletes Hive app_storage box (legacy FF1 devices). Prevents migration
    /// from re-importing devices after Forget I Exist.
    clearLegacyHive: () async {
      try {
        await Hive.initFlutter();
        if (Hive.isBoxOpen('app_storage')) {
          await Hive.box<String>('app_storage').close();
        }
        await Hive.deleteBoxFromDisk('app_storage');
      } on Object {
        // Box may not exist; ignore.
      } finally {
        await Hive.close();
      }
    },
    invalidateListProvidersBeforeDbClose: invalidateDatabaseConsumerProviders,
    invalidateReconnectInfraProviders: invalidateDatabaseConnectionProviders,
    invalidateProvidersForRebind: invalidateDatabaseConsumerProviders,
  );
});
