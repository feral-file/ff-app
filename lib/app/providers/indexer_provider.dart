import 'dart:async';

import 'package:app/infra/config/app_config.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/graphql/indexer_client_provider.dart';
import 'package:app/infra/services/dp1_playlist_items_enrichment_service.dart';
import 'package:app/infra/services/indexer_address_indexing_service.dart';
import 'package:app/infra/services/indexer_enrichment_scheduler_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

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
  late final Logger _log;
  late final IndexerService _indexerService;
  late final IndexerSyncService _indexerSyncService;
  late final DP1PlaylistItemsEnrichmentService _enrichmentService;
  late final IndexerEnrichmentSchedulerService _scheduler;
  late final IndexerAddressIndexingService _addressIndexingService;

  @override
  IndexerState build() {
    _log = Logger('IndexerNotifier');

    final client = ref.watch(indexerClientProvider);
    final databaseService = ref.watch(databaseServiceProvider);

    _indexerService = IndexerService(client: client);
    _indexerSyncService = IndexerSyncService(
      indexerService: _indexerService,
      databaseService: databaseService,
    );
    _enrichmentService = DP1PlaylistItemsEnrichmentService(
      indexerService: _indexerService,
      databaseService: databaseService,
    );
    _scheduler = IndexerEnrichmentSchedulerService(
      enrichmentService: _enrichmentService,
      indexerSyncService: _indexerSyncService,
      maxEnrichmentWorkers: AppConfig.indexerEnrichmentMaxThreads,
    );
    _addressIndexingService = IndexerAddressIndexingService();

    ref.onDispose(() {
      unawaited(_addressIndexingService.dispose());
    });

    return const IndexerState();
  }

  /// Expose network-only indexer service for callers needing raw queries.
  IndexerService get service => _indexerService;

  /// Expose address sync service for callers needing direct sync operations.
  IndexerSyncService get syncService => _indexerSyncService;

  /// Expose enrichment service for callers needing direct batch operations.
  DP1PlaylistItemsEnrichmentService get enrichmentService => _enrichmentService;

  /// Expose isolate-backed address indexing service.
  IndexerAddressIndexingService get addressIndexingService =>
      _addressIndexingService;

  /// Enqueue personal address processing and run shared loop.
  void enqueuePersonalAddress(String address) {
    _scheduler.enqueuePersonalAddress(address);
  }

  /// Notify scheduler that feed ingestion created new enrichable items.
  void notifyFeedWorkAvailable() {
    _scheduler.notifyFeedWorkAvailable();
  }

  /// Run shared `high -> low -> personal(50)` loop until idle.
  Future<bool> processUntilIdle() async {
    try {
      return await _scheduler.processUntilIdle();
    } on Object catch (e, stack) {
      _log.warning('Indexer scheduler failed', e, stack);
      state = IndexerState(lastError: e);
      return false;
    }
  }

  /// Run feed enrichment process only.
  Future<bool> processFeedEnrichmentUntilIdle() async {
    try {
      return await _scheduler.processFeedEnrichmentUntilIdle();
    } on Object catch (e, stack) {
      _log.warning('Feed enrichment process failed', e, stack);
      state = IndexerState(lastError: e);
      return false;
    }
  }

  /// Run personal-address sync process only.
  Future<bool> processAddressBatchUntilIdle() async {
    try {
      return await _scheduler.processAddressQueueUntilIdle();
    } on Object catch (e, stack) {
      _log.warning('Address batch process failed', e, stack);
      state = IndexerState(lastError: e);
      return false;
    }
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

  /// Expose shared scheduler for compatibility call-sites.
  IndexerEnrichmentSchedulerService get scheduler => _scheduler;
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

/// Compatibility provider: feed playlist-item enrichment service.
final dp1PlaylistItemsEnrichmentServiceProvider =
    Provider<DP1PlaylistItemsEnrichmentService>((ref) {
      return ref.watch(indexerProvider.notifier).enrichmentService;
    });

/// Compatibility provider: shared indexer scheduler service.
final indexerEnrichmentSchedulerServiceProvider =
    Provider<IndexerEnrichmentSchedulerService>((ref) {
      return ref.watch(indexerProvider.notifier).scheduler;
    });

/// Compatibility provider: isolate-backed address indexing service.
final indexerAddressIndexingServiceProvider =
    Provider<IndexerAddressIndexingService>((ref) {
      return ref.watch(indexerProvider.notifier).addressIndexingService;
    });
