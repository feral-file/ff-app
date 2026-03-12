// ignore_for_file: public_member_api_docs // Reason: service API covered by plan.

import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/sync_collection.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/domain/utils/token_event_grouping.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/token_transformer.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart'
    show PersonalTokensSyncService;
import 'package:logging/logging.dart';

/// Updates already-fetched tokens of address. Used for incremental sync
/// (transfers, metadata updates, removals). Calls syncCollection with checkpoint,
/// groups events into removal vs updated, fetches tokens by IDs, then applies
/// removals and ingests. This is independent of [PersonalTokensSyncService.syncAddresses]
/// which fetches tokens for address initially.
///
/// Checkpoint is saved only after processing completes successfully.
/// On failure, the next timer tick retries with the same checkpoint.
class AddressSyncCollectionService {
  AddressSyncCollectionService({
    required IndexerService indexerService,
    required DatabaseService databaseService,
    required AppStateServiceBase appStateService,
    Logger? logger,
  }) : _indexerService = indexerService,
       _databaseService = databaseService,
       _appStateService = appStateService,
       _log = logger ?? Logger('AddressSyncCollectionService');

  final IndexerService _indexerService;
  final DatabaseService _databaseService;
  final AppStateServiceBase _appStateService;
  final Logger _log;

  static const int _limit = 255;
  static const int _maxPaginationIterations = 100;

  /// Sync address collection via syncCollection. Saves checkpoint only on success.
  Future<void> syncAddressWithCollection(String address) async {
    final normalizedAddress = address.toNormalizedAddress();
    final savedCheckpoint = await _appStateService.getAddressCheckpoint(
      normalizedAddress,
    );

    var checkpoint = savedCheckpoint;
    if (checkpoint == null) {
      return;
    }

    var iteration = 0;
    while (iteration < _maxPaginationIterations) {
      iteration++;

      final request = QuerySyncCollectionRequest(
        address: normalizedAddress,
        checkpoint: checkpoint!,
      );

      final result = await _indexerService.syncCollection(request);

      if (result.events.isEmpty) {
        if (result.nextCheckpoint != null) {
          await _appStateService.setAddressCheckpoint(
            address: normalizedAddress,
            checkpoint: result.nextCheckpoint!,
          );
          checkpoint = result.nextCheckpoint;
        } else {
          return;
        }
        continue;
      }

      final tokenIds = result.events.map((e) => e.tokenId).toSet().toList();
      if (tokenIds.isEmpty) {
        if (result.nextCheckpoint != null) {
          await _appStateService.setAddressCheckpoint(
            address: normalizedAddress,
            checkpoint: result.nextCheckpoint!,
          );
          checkpoint = result.nextCheckpoint;
        }
        if (result.events.length < _limit) return;
        continue;
      }

      final grouping = groupTokenEvents(
        events: result.events,
        address: normalizedAddress,
      );

      // Removal: fetch without owners so transferred-out tokens are returned.
      // Indexer filters by owners at query level; transferred tokens are excluded
      // when owners filter is applied, so removalCids would stay empty.
      var removalCids = const <String>[];
      if (grouping.removalTokenIds.isNotEmpty) {
        final removalTokens = await _indexerService.getManualTokens(
          tokenIds: grouping.removalTokenIds.toList(),
        );
        final removalById = {for (final t in removalTokens) t.id: t};
        removalCids = grouping.removalTokenIds
            .map((id) => removalById[id]?.cid)
            .whereType<String>()
            .where((c) => c.isNotEmpty)
            .toList();
      }

      // Updated: fetch with owners filter for server-side accuracy.
      // Avoids false negatives when indexer returns truncated owner lists.
      var updatedTokens = const <AssetToken>[];
      if (grouping.updatedTokenIds.isNotEmpty) {
        final tokens = await _indexerService.getManualTokens(
          tokenIds: grouping.updatedTokenIds.toList(),
          owners: [normalizedAddress],
        );
        final tokenById = {for (final t in tokens) t.id: t};
        updatedTokens = grouping.updatedTokenIds
            .map((id) => tokenById[id])
            .whereType<AssetToken>()
            .toList();
      }

      if (removalCids.isNotEmpty) {
        await _databaseService.deleteTokensByCids(
          address: normalizedAddress,
          cids: removalCids,
        );
      }

      if (updatedTokens.isNotEmpty) {
        final owned = TokenTransformer.filterTokensByOwner(
          tokens: updatedTokens,
          ownerAddress: normalizedAddress,
        );
        if (owned.isNotEmpty) {
          await _databaseService.ingestTokensForAddress(
            address: normalizedAddress,
            tokens: owned,
          );
        }
      }

      if (result.nextCheckpoint != null) {
        await _appStateService.setAddressCheckpoint(
          address: normalizedAddress,
          checkpoint: result.nextCheckpoint!,
        );
        checkpoint = result.nextCheckpoint;
      }

      if (result.events.length < _limit) {
        return;
      }
    }

    _log.warning(
      'syncAddressWithCollection hit max pagination iterations for $normalizedAddress',
    );
  }
}
