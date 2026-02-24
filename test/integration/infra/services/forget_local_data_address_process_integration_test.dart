import 'dart:async';

import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/address_indexing_process_service.dart';
import 'package:app/infra/services/forget_local_data_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/integration_test_harness.dart';

class _FakeIndexerClient extends IndexerClient {
  _FakeIndexerClient() : super(endpoint: 'https://example.invalid');
}

class _FakeIndexerService extends IndexerService {
  _FakeIndexerService() : super(client: _FakeIndexerClient());

  @override
  Future<List<AddressIndexingResult>> indexAddressesList(
    List<String> addresses,
  ) async {
    return addresses
        .map(
          (address) => AddressIndexingResult(
            address: address,
            workflowId: 'wf-$address',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<AddressIndexingJobResponse> getAddressIndexingJobStatus({
    required String workflowId,
  }) async {
    return AddressIndexingJobResponse(
      workflowId: workflowId,
      address: '',
      status: IndexingJobStatus.completed,
      totalTokensIndexed: 354,
      totalTokensViewable: 354,
    );
  }
}

class _TestAppStateService implements AppStateService {
  final Map<String, AddressIndexingProcessStatus> _statuses =
      <String, AddressIndexingProcessStatus>{};

  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {
    _statuses[address] = status;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PagedIndexerSyncService extends IndexerSyncService {
  _PagedIndexerSyncService({
    required this.databaseService,
    required this.targetAddress,
  }) : super(
         indexerService: _FakeIndexerService(),
         databaseService: databaseService,
       );

  final DatabaseService databaseService;
  final String targetAddress;
  final Completer<void> lastBatchStarted = Completer<void>();

  @override
  Future<AddressSyncPageResult> syncTokensPageForAddress({
    required String address,
    int? limit,
    int? offset,
  }) async {
    final currentOffset = offset ?? 0;
    if (currentOffset >= 354) {
      return const AddressSyncPageResult(fetchedCount: 0, nextOffset: null);
    }

    final remaining = 354 - currentOffset;
    final pageSize = remaining > 50 ? 50 : remaining;

    if (currentOffset == 350) {
      if (!lastBatchStarted.isCompleted) {
        lastBatchStarted.complete();
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }

    await databaseService.ingestTokensForAddress(
      address: targetAddress,
      tokens: _tokens(
        address: targetAddress,
        startTokenId: currentOffset + 1,
        count: pageSize,
      ),
    );

    final nextOffset = currentOffset + pageSize;
    return AddressSyncPageResult(
      fetchedCount: pageSize,
      nextOffset: nextOffset >= 354 ? null : nextOffset,
    );
  }

  List<AssetToken> _tokens({
    required String address,
    required int startTokenId,
    required int count,
  }) {
    return List<AssetToken>.generate(count, (index) {
      final tokenId = startTokenId + index;
      return AssetToken(
        id: tokenId,
        cid: 'eip155:1:erc721:0xcontract:$tokenId',
        chain: 'eip155:1',
        standard: 'erc721',
        contractAddress: '0xcontract',
        tokenNumber: '$tokenId',
        currentOwner: address.toUpperCase(),
      );
    }, growable: false);
  }
}

void main() {
  group('Forget local data with running address indexing process', () {
    late IntegrationTestContext context;

    setUp(() async {
      context = await createIntegrationTestContext();
    });

    tearDown(() async {
      await context.dispose();
    });

    Future<void> seedAddressPlaylist(String address) async {
      final now = DateTime.now().toUtc();
      await context.databaseService.ingestPlaylist(
        PlaylistExt.fromWalletAddress(
          WalletAddress(
            address: address,
            createdAt: now,
            name: address,
          ),
        ),
      );
    }

    Future<int> personalEntryCount() async {
      final row = await context.database.customSelect(
        '''
            SELECT COUNT(*) AS count
            FROM playlist_entries pe
            JOIN playlists p ON p.id = pe.playlist_id
            WHERE p.type = 1
            ''',
      ).getSingle();
      return row.read<int>('count');
    }

    test(
      'reproduces 4 leftover personal items when process is not stopped',
      () async {
        const address = '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8';
        await seedAddressPlaylist(address);

        final indexerService = _FakeIndexerService();
        final syncService = _PagedIndexerSyncService(
          databaseService: context.databaseService,
          targetAddress: address,
        );
        final processService = AddressIndexingProcessService(
          indexerService: indexerService,
          indexerSyncService: syncService,
          appStateService: _TestAppStateService(),
        );

        await processService.start(address);
        await syncService.lastBatchStarted.future;

        final forget = ForgetLocalDataService(
          stopWorkersGracefully: () async {},
          checkpointDatabase: context.databaseService.checkpoint,
          truncateDatabase: context.databaseService.clearAll,
          clearObjectBoxData: () async {},
          pauseFeedWork: () {},
          pauseTokenPolling: () {},
          enablePostDrainSweep: false,
        );

        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 60), () async {
            await seedAddressPlaylist(address);
          }),
        );

        await forget.forgetIExist();
        await Future<void>.delayed(const Duration(milliseconds: 180));

        expect(await personalEntryCount(), equals(4));
      },
    );

    test(
      'stopping and draining address process before truncate clears all',
      () async {
        const address = '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8';
        await seedAddressPlaylist(address);

        final indexerService = _FakeIndexerService();
        final syncService = _PagedIndexerSyncService(
          databaseService: context.databaseService,
          targetAddress: address,
        );
        final processService = AddressIndexingProcessService(
          indexerService: indexerService,
          indexerSyncService: syncService,
          appStateService: _TestAppStateService(),
        );

        await processService.start(address);
        await syncService.lastBatchStarted.future;

        final forget = ForgetLocalDataService(
          stopWorkersGracefully: processService.stopAllAndDrainForReset,
          checkpointDatabase: context.databaseService.checkpoint,
          truncateDatabase: context.databaseService.clearAll,
          clearObjectBoxData: () async {},
          pauseFeedWork: () {},
          pauseTokenPolling: () {},
          enablePostDrainSweep: false,
        );

        unawaited(
          Future<void>.delayed(const Duration(milliseconds: 60), () async {
            await seedAddressPlaylist(address);
          }),
        );

        await forget.forgetIExist();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(await personalEntryCount(), equals(0));
      },
    );
  });
}
