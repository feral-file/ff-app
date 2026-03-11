import 'dart:async';

import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/extensions/playlist_ext.dart';
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

// ignore_for_file: cascade_invocations // Reason: provider wiring uses concise imperative call order for cleanup flow.

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
  String normalizeAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return trimmed.toLowerCase();
    }
    return trimmed;
  }

  Future<void> rebindDatabaseProviders() async {
    final r = ref;
    r.invalidate(appDatabaseProvider);
    r.invalidate(databaseServiceProvider);
    r.invalidate(seedDownloadProvider);
  }

  Future<void> forceReplaceDatabaseFromSeed() async {
    await ref
        .read(seedDatabaseSyncServiceProvider)
        .forceReplace(
          beforeReplace: () async {
            await ref.read(databaseServiceProvider).close();
            await ref.read(seedDatabaseServiceProvider).deleteDatabaseFiles();
          },
          afterReplace: rebindDatabaseProviders,
        );
  }

  return LocalDataCleanupService(
    stopWorkersGracefully: () async {
      await ref
          .read(tokensSyncCoordinatorProvider.notifier)
          .stopAndDrainForReset();
      final r = ref;
      r.invalidate(tokensSyncCoordinatorProvider);
    },
    closeAndDeleteDatabase: () async {
      final seedDatabaseService = ref.read(seedDatabaseServiceProvider);
      await ref.read(databaseServiceProvider).close();
      await seedDatabaseService.deleteDatabaseFiles();

      // Force all DB-backed dependencies to bind against a new DB instance.
      final r = ref;
      r.invalidate(appDatabaseProvider);
      r.invalidate(databaseServiceProvider);
    },
    clearObjectBoxData: () async {
      await ref.read(objectBoxLocalDataCleanerProvider).clearAll();
    },
    clearPendingAddresses: () async {
      await ref.read(pendingAddressesStoreProvider).clear();
    },
    clearCachedImages: () async {
      await CachedNetworkImageProvider.defaultCacheManager.emptyCache();
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    },
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
    getFavoritePlaylistsSnapshot: () async {
      final databaseService = ref.read(databaseServiceProvider);
      return databaseService.getFavoritePlaylistsSnapshot();
    },
    restoreFavoritePlaylists: (snapshots) async {
      final databaseService = ref.read(databaseServiceProvider);
      await databaseService.restoreFavoritePlaylistsSnapshot(snapshots);
    },
    runBootstrap: () async {
      await ref.read(bootstrapProvider.notifier).bootstrap();
    },
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
    recreateDatabaseFromSeed: () async {
      await forceReplaceDatabaseFromSeed();
    },
    pauseFeedWork: () {
      // No-op: feed manager removed; seed database is the source of DP1 data.
    },
    pauseTokenPolling: () {
      ref.read(tokensSyncCoordinatorProvider.notifier).pausePolling();
    },
    onResetCompleted: () async {
      await forceReplaceDatabaseFromSeed();
      await ref.read(bootstrapProvider.notifier).bootstrap();
    },
    clearLegacySqlite: () async {
      await LegacyStorageLocator().deleteLegacySqlite();
    },
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
