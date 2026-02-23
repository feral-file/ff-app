import 'dart:async';

import 'package:app/app/providers/background_workers_provider.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/graphql/indexer_client_provider.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State surface for indexer orchestration.
class IndexerState {
  /// Creates an [IndexerState].
  const IndexerState({
    this.lastError,
  });

  /// Latest non-fatal orchestration error.
  final Object? lastError;
}

/// Single indexer flow-driver provider.
///
/// Covers:
/// 1) Enrichment batching (high/low)
/// 2) Trigger address indexing
/// 3) Watch indexing status
/// 4) Fetch/sync address tokens in batches of 50 (via scheduler)
class IndexerNotifier extends Notifier<IndexerState> {
  late final IndexerService _indexerService;
  late final IndexerSyncService _indexerSyncService;

  @override
  IndexerState build() {
    final client = ref.watch(indexerClientProvider);
    final databaseService = ref.watch(databaseServiceProvider);

    _indexerService = IndexerService(client: client);
    _indexerSyncService = IndexerSyncService(
      indexerService: _indexerService,
      databaseService: databaseService,
    );

    return const IndexerState();
  }

  /// Expose network-only indexer service for callers needing raw queries.
  IndexerService get service => _indexerService;

  /// Expose address sync service for callers needing direct sync operations.
  IndexerSyncService get syncService => _indexerSyncService;

  /// Enqueue personal address processing and run shared loop.
  void enqueuePersonalAddress(String address) {
    unawaited(ref.read(workerSchedulerProvider).onAddressAdded(address));
  }

  /// Notify scheduler that feed ingestion created new enrichable items.
  void notifyFeedWorkAvailable() {
    unawaited(ref.read(workerSchedulerProvider).onFeedIngested());
  }

  /// Notify scheduler that feed-channel data is available for enrichment.
  ///
  /// Routes through [WorkerScheduler.onFeedIngested] so enrichment is handled
  /// by the worker fleet rather than the main isolate.
  Future<void> processFeedEnrichmentUntilIdle() {
    return ref.read(workerSchedulerProvider).onFeedIngested();
  }

  /// Trigger indexing for address list.
  Future<List<AddressIndexingResult>> triggerAddressIndexing(
    List<String> addresses,
  ) async {
    return _indexerService.indexAddressesList(addresses);
  }

  /// Get address indexing workflow status by workflowId.
  Future<AddressIndexingJobResponse> getAddressIndexingStatus({
    required String workflowId,
  }) async {
    return _indexerService.getAddressIndexingJobStatus(workflowId: workflowId);
  }

  /// Fetch/sync one batch for addresses (50 by default).
  Future<int> syncAddressTokensBatch({
    required List<String> addresses,
    int limit = 50,
    int offset = 0,
  }) async {
    return _indexerSyncService.syncTokensForAddresses(
      addresses: addresses,
      limit: limit,
      offset: offset,
    );
  }

}

/// Single source of truth for all indexer orchestration.
final indexerProvider = NotifierProvider<IndexerNotifier, IndexerState>(
  IndexerNotifier.new,
);

/// Compatibility provider: raw indexer service.
final indexerServiceProvider = Provider<IndexerService>((ref) {
  return ref.watch(indexerProvider.notifier).service;
});

/// Compatibility provider: address token sync service.
final indexerSyncServiceProvider = Provider<IndexerSyncService>((ref) {
  return ref.watch(indexerProvider.notifier).syncService;
});
