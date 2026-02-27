import 'dart:async';

import 'package:app/app/feed/feed_registry_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_local_data_cleaner.dart';
import 'package:app/infra/services/local_data_cleanup_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  return LocalDataCleanupService(
    stopWorkersGracefully: () async {
      await ref.read(feedManagerProvider).pauseAndDrainWork();
      await ref
          .read(tokensSyncCoordinatorProvider.notifier)
          .stopAndDrainForReset();
      final r = ref;
      r.invalidate(tokensSyncCoordinatorProvider);
    },
    checkpointDatabase: () async {
      await ref.read(databaseServiceProvider).checkpoint();
    },
    truncateDatabase: () async {
      await ref.read(databaseServiceProvider).clearAll();
    },
    clearObjectBoxData: () async {
      await ref.read(objectBoxLocalDataCleanerProvider).clearAll();
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
    refetchFromBeginning: (addresses) async {
      final normalizedAddresses = addresses
          .map(normalizeAddress)
          .toSet()
          .toList();
      final appState = ref.read(appStateServiceProvider);
      for (final address in normalizedAddresses) {
        await appState.clearAddressAnchor(address);
      }

      final feedManager = ref.read(feedManagerProvider);
      feedManager.resumeWork();

      TokensSyncCoordinatorNotifier? coordinator;
      if (normalizedAddresses.isNotEmpty) {
        coordinator = ref.read(tokensSyncCoordinatorProvider.notifier);
      }

      await Future.wait<void>([
        feedManager.reloadAllCache(force: true),
        if (normalizedAddresses.isNotEmpty)
          coordinator!.syncAddresses(normalizedAddresses),
      ]);
    },
    pauseFeedWork: () {
      ref.read(feedManagerProvider).pauseWork();
    },
    pauseTokenPolling: () {
      ref.read(tokensSyncCoordinatorProvider.notifier).pausePolling();
    },
    onResetCompleted: () async {
      final feedManager = ref.read(feedManagerProvider);
      feedManager.resumeWork();
      unawaited(feedManager.reloadAllCache(force: true));
    },
  );
});
