import 'dart:io';

import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/objectbox.g.dart' show openStore;
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/address_indexing_process_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';

class _FakeIndexerClient extends IndexerClient {
  _FakeIndexerClient() : super(endpoint: 'http://localhost');
}

class _FakeDatabaseService extends DatabaseService {
  _FakeDatabaseService()
    : this._(AppDatabase.forTesting(NativeDatabase.memory()));

  _FakeDatabaseService._(this._ownedDb) : super(_ownedDb);

  final AppDatabase _ownedDb;

  @override
  Future<void> close() => _ownedDb.close();
}

class _FakeIndexerService extends IndexerService {
  _FakeIndexerService() : super(client: _FakeIndexerClient());

  @override
  Future<List<AddressIndexingResult>> indexAddressesList(
    List<String> addresses,
  ) async {
    return [
      for (final address in addresses)
        AddressIndexingResult(address: address, workflowId: 'wf-$address'),
    ];
  }

  @override
  Future<AddressIndexingJobResponse> getAddressIndexingJobStatus({
    required String workflowId,
  }) async {
    return AddressIndexingJobResponse(
      workflowId: workflowId,
      address: workflowId.replaceFirst('wf-', ''),
      status: IndexingJobStatus.completed,
      totalTokensIndexed: null,
      totalTokensViewable: null,
    );
  }
}

class _FakeIndexerSyncService extends IndexerSyncService {
  _FakeIndexerSyncService({
    required super.indexerService,
    required super.databaseService,
    required List<AddressSyncPageResult> pages,
  }) : _pages = List<AddressSyncPageResult>.from(pages);

  final List<AddressSyncPageResult> _pages;
  final List<int?> requestedOffsets = <int?>[];

  @override
  Future<AddressSyncPageResult> syncTokensPageForAddress({
    required String address,
    int? limit,
    int? offset,
  }) async {
    requestedOffsets.add(offset);
    if (_pages.isEmpty) {
      return const AddressSyncPageResult(fetchedCount: 0);
    }
    return _pages.removeAt(0);
  }
}

void main() {
  group('AddressIndexingProcessService', () {
    late Directory tempDir;
    late Store objectBoxStore;
    late AppStateService appStateService;
    late _FakeDatabaseService databaseService;
    late _FakeIndexerService indexerService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('addr_idx_proc_');
      objectBoxStore = await openStore(directory: tempDir.path);
      appStateService = AppStateService(
        appStateBox: objectBoxStore.box<AppStateEntity>(),
        appStateAddressBox: objectBoxStore.box<AppStateAddressEntity>(),
      );
      databaseService = _FakeDatabaseService();
      indexerService = _FakeIndexerService();
    });

    tearDown(() async {
      await databaseService.close();
      objectBoxStore.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
      'uses response offset cursor paging after workflow completes',
      () async {
        final syncService = _FakeIndexerSyncService(
          indexerService: indexerService,
          databaseService: databaseService,
          pages: const [
            AddressSyncPageResult(fetchedCount: 50, nextOffset: 50),
            AddressSyncPageResult(fetchedCount: 50, nextOffset: 100),
            AddressSyncPageResult(fetchedCount: 12),
          ],
        );

        final service = AddressIndexingProcessService(
          indexerService: indexerService,
          indexerSyncService: syncService,
          appStateService: appStateService,
        );

        const address = '0xabc';
        await service.start(address);
        await _waitForFinalState(appStateService, address);

        expect(syncService.requestedOffsets, equals([0, 50, 100]));

        final status = await appStateService.getAddressIndexingStatus(address);
        expect(status?.state, AddressIndexingProcessState.completed);
      },
    );

    test('stops when next offset is null', () async {
      final syncService = _FakeIndexerSyncService(
        indexerService: indexerService,
        databaseService: databaseService,
        pages: const [
          AddressSyncPageResult(fetchedCount: 50, nextOffset: 50),
          AddressSyncPageResult(fetchedCount: 10),
        ],
      );

      final service = AddressIndexingProcessService(
        indexerService: indexerService,
        indexerSyncService: syncService,
        appStateService: appStateService,
      );

      const address = '0xdef';
      await service.start(address);
      await _waitForFinalState(appStateService, address);

      expect(syncService.requestedOffsets, equals([0, 50]));

      final status = await appStateService.getAddressIndexingStatus(address);
      expect(status?.state, AddressIndexingProcessState.completed);
    });
  });
}

Future<void> _waitForFinalState(
  AppStateService store,
  String address,
) async {
  final startedAt = DateTime.now();
  while (DateTime.now().difference(startedAt) < const Duration(seconds: 2)) {
    final status = await store.getAddressIndexingStatus(address);
    if (status == null) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      continue;
    }
    if (status.state == AddressIndexingProcessState.completed ||
        status.state == AddressIndexingProcessState.failed ||
        status.state == AddressIndexingProcessState.paused ||
        status.state == AddressIndexingProcessState.stopped) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Timed out waiting for final indexing state for $address');
}
