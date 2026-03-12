import 'dart:async';

import 'package:app/app/providers/addresses_provider.dart';
import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/me_section_playlists_provider.dart';
import 'package:app/app/providers/playlist_details_provider.dart';
import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/providers/works_provider.dart';
import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_local_data_cleaner.dart';
import 'package:app/infra/services/legacy_storage_locator.dart';
import 'package:app/infra/services/local_data_cleanup_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';

// ignore_for_file: cascade_invocations // Reason: provider wiring uses concise imperative call order for cleanup flow.

/// Wires [LocalDataCleanupService] for two flows:
///
/// 1. **clearLocalData** (Forget I Exist): full reset → deletes SQLite,
///    ObjectBox, legacy files, then replaces DB from seed and bootstraps.
/// 2. **rebuildMetadata**: preserves addresses/favorites, replaces SQLite
///    from seed, restores and refetches.

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
  /// Normalizes address for deduplication (Ethereum: lowercase; Tezos: as-is).
  String normalizeAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return trimmed.toLowerCase();
    }
    return trimmed;
  }

  /// Invalidates DB-related and UI providers so they rebind to the new DB
  /// after seed replacement. Called from [forceReplaceDatabaseFromSeed]'s
  /// afterReplace once the seed file is placed.
  Future<void> rebindDatabaseProviders() async {
    final r = ref;
    r.invalidate(channelsProvider(ChannelType.dp1));
    r.invalidate(channelsProvider(ChannelType.localVirtual));
    r.invalidate(playlistsProvider(PlaylistType.dp1));
    r.invalidate(playlistsProvider(PlaylistType.addressBased));
    r.invalidate(meSectionPlaylistsProvider);
    r.invalidate(isWorkInFavoriteProvider);
    r.invalidate(favoritePlaylistServiceProvider);
    r.invalidate(playlistsProvider(PlaylistType.favorite));
    r.invalidate(playlistDetailsProvider);
    r.invalidate(worksProvider);
    r.invalidate(addressesProvider);
    r.invalidate(appDatabaseProvider);
    r.invalidate(databaseServiceProvider);
    r.invalidate(seedDownloadProvider);
  }

  /// Downloads seed from S3 (or cache), replaces local dp1_library.sqlite,
  /// then rebinds providers.
  ///
  /// Updates [seedDownloadProvider] so Home tabs show loading during download.
  Future<void> forceReplaceDatabaseFromSeed() async {
    final log = Logger('LocalDataCleanupProvider');
    final seedNotifier = ref.read(seedDownloadProvider.notifier);
    seedNotifier.notifyForceReplaceStarted();

    var lastLoggedPct = -1;
    try {
      await ref
          .read(seedDatabaseSyncServiceProvider)
          .forceReplace(
            beforeReplace: () async {
              await ref.read(databaseServiceProvider).close();
              await ref.read(seedDatabaseServiceProvider).deleteDatabaseFiles();
            },
            afterReplace: rebindDatabaseProviders,
            onProgress: (progress) {
              seedNotifier.notifyForceReplaceProgress(progress);
              final pct = (progress * 100).round();
              if (pct >= lastLoggedPct + 1 || pct >= 100) {
                lastLoggedPct = pct;
                log.info('Seed database download progress: $pct%');
              }
            },
          );
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
    /// Drains token sync workers and invalidates coordinator.
    stopWorkersGracefully: () async {
      await ref
          .read(tokensSyncCoordinatorProvider.notifier)
          .stopAndDrainForReset();
      final r = ref;
      r.invalidate(tokensSyncCoordinatorProvider);
    },

    /// Closes the DB and deletes SQLite files. Does NOT invalidate providers
    /// here, so nothing triggers a DB open while the file is missing. Providers
    /// are invalidated in [rebindDatabaseProviders] after the seed is placed.
    closeAndDeleteDatabase: () async {
      final seedDatabaseService = ref.read(seedDatabaseServiceProvider);
      await ref.read(databaseServiceProvider).close();
      await seedDatabaseService.deleteDatabaseFiles();
    },

    /// Clears FF1 devices, app state, tracked addresses, etc.
    clearObjectBoxData: () async {
      await ref.read(objectBoxLocalDataCleanerProvider).clearAll();
    },

    /// Deletes pending_addresses.json (addresses queued before DB ready).
    clearPendingAddresses: () async {
      await ref.read(pendingAddressesStoreProvider).clear();
    },

    /// Clears CachedNetworkImage and Flutter image cache.
    clearCachedImages: () async {
      await CachedNetworkImageProvider.defaultCacheManager.emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    },

    /// Collects personal addresses from SQLite playlists + ObjectBox statuses
    /// (used by rebuildMetadata to preserve them).
    getPersonalAddresses: () async {
      final databaseService = ref.read(databaseServiceProvider);
      final playlists = await databaseService.getAddressPlaylists();
      final appState = ref.read(appStateServiceProvider);
      final statuses = await appState.getAllAddressIndexingStatuses();

      final addressesFromOwners = playlists
          .map((playlist) => playlist.ownerAddress)
          .whereType<String>()
          .toSet();

      final addressesFromPlaylistIds = playlists
          .map((playlist) {
            final parts = playlist.id.split(':');
            if (parts.length < 3 || parts.first != 'addr') {
              return null;
            }
            return parts.sublist(2).join(':');
          })
          .whereType<String>()
          .toSet();

      final addressesFromStatuses = statuses.keys.toSet();

      return <String>{
        ...addressesFromOwners,
        ...addressesFromPlaylistIds,
        ...addressesFromStatuses,
      }.map(normalizeAddress).toSet().toList();
    },

    /// Restores address-based playlists to SQLite (rebuildMetadata only).
    restorePersonalAddressPlaylists: (addresses) async {
      final databaseService = ref.read(databaseServiceProvider);
      final now = DateTime.now().toUtc();
      for (final address in addresses) {
        await databaseService.ingestPlaylist(
          PlaylistExt.fromWalletAddress(
            WalletAddress(
              address: address,
              createdAt: now,
              name: address,
            ),
          ),
        );
      }
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

    /// Clears indexing anchors and re-syncs addresses from indexer
    /// (rebuildMetadata only).
    refetchFromBeginning: (addresses) async {
      final normalizedAddresses = addresses
          .map(normalizeAddress)
          .toSet()
          .toList();
      final appState = ref.read(appStateServiceProvider);
      for (final address in normalizedAddresses) {
        await appState.clearAddressAnchor(address);
      }

      if (normalizedAddresses.isNotEmpty) {
        final coordinator = ref.read(tokensSyncCoordinatorProvider.notifier);
        await coordinator.syncAddresses(normalizedAddresses);
      }
    },

    /// Replaces SQLite with seed. Used by rebuildMetadata (not clearLocalData).
    recreateDatabaseFromSeed: () async {
      await forceReplaceDatabaseFromSeed();
    },
    pauseFeedWork: () {
      // No-op: feed manager removed; seed database is the source of DP1 data.
    },
    pauseTokenPolling: () {
      ref.read(tokensSyncCoordinatorProvider.notifier).pausePolling();
    },

    /// Called at end of clearLocalData (Forget I Exist): replace DB from seed
    /// and bootstrap so app can start fresh on onboarding.
    onResetCompleted: () async {
      Future<void> future() async {
        await forceReplaceDatabaseFromSeed();
        await ref.read(bootstrapProvider.notifier).bootstrap();
      }

      unawaited(future());
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
  );
});
