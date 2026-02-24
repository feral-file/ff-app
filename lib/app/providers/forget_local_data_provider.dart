import 'dart:async';

import 'package:app/app/feed/feed_registry_provider.dart';
import 'package:app/app/providers/background_workers_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_local_data_cleaner.dart';
import 'package:app/infra/services/forget_local_data_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for ObjectBox local data cleanup.
final objectBoxLocalDataCleanerProvider = Provider<ObjectBoxLocalDataCleaner>((
  ref,
) {
  final store = getInitializedObjectBoxStore();
  return ObjectBoxLocalDataCleaner(store);
});

/// Provider for the "Forget I exist" local reset flow.
final forgetLocalDataServiceProvider = Provider<ForgetLocalDataService>((ref) {
  return ForgetLocalDataService(
    stopWorkersGracefully: () async {
      await ref.read(feedManagerProvider).pauseAndDrainWork();
      await ref
          .read(addressIndexingProcessServiceProvider)
          .stopAllAndDrainForReset();
      await ref
          .read(tokensSyncCoordinatorProvider.notifier)
          .stopAndDrainForReset();
      await ref.read(workerSchedulerProvider).stopAll();
      final r = ref;
      r
        ..invalidate(addressIndexingProcessServiceProvider)
        ..invalidate(workerSchedulerProvider)
        ..invalidate(indexerTokensWorkerProvider)
        ..invalidate(tokensSyncCoordinatorProvider);
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
    pauseFeedWork: () {
      ref.read(feedManagerProvider).pauseWork();
    },
    pauseTokenPolling: () {
      ref.read(tokensSyncCoordinatorProvider.notifier).pausePolling();
    },
    onResetCompleted: () async {
      final appState = ref.read(appStateServiceProvider);
      await appState.setLastTimeRefreshFeeds(DateTime(1970, 1, 1));

      final feedManager = ref.read(feedManagerProvider);
      feedManager.resumeWork();
      unawaited(feedManager.reloadAllCache(force: true));
    },
  );
});
