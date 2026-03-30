import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/models/indexer/workflow.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/graphql/indexer_client_provider.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infra/services/fake_indexer_service_isolate.dart';
import 'provider_test_helpers.dart';

/// Fake app state that returns [WalletAddress] with alias for
/// [getTrackedWalletAddresses]. Used to verify alias preservation.
class _FakeAppStateForAliasTest implements AppStateService {
  _FakeAppStateForAliasTest({
    required this.walletAddresses,
    this.statuses = const {},
  });

  final List<WalletAddress> walletAddresses;
  final Map<String, AddressIndexingProcessStatus> statuses;

  @override
  Future<List<WalletAddress>> getTrackedWalletAddresses() async =>
      List.from(walletAddresses);

  @override
  Future<List<String>> getTrackedPersonalAddresses() async =>
      walletAddresses.map((wa) => wa.address).toList();

  @override
  Future<Map<String, AddressIndexingProcessStatus>>
  getAllAddressIndexingStatuses() async => Map.fromEntries(statuses.entries);

  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {}

  @override
  Future<void> addTrackedAddress(String address, {String alias = ''}) async {}

  @override
  Future<bool> hasSeenOnboarding() async => false;

  @override
  Future<void> setHasSeenOnboarding({required bool hasSeen}) async {}

  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) => Stream.value(statuses[address]);

  @override
  Future<int?> getPersonalTokensListFetchOffset(String address) async => null;

  @override
  Future<void> setPersonalTokensListFetchOffset({
    required String address,
    required int? nextFetchOffset,
  }) async {}

  @override
  Future<void> clearAllPersonalTokensListFetchOffsets() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test(
    'ensureTrackedAddressesHavePlaylistsAndResume preserves alias in '
    'playlist name',
    () async {
      await ensureDotEnvLoaded();
      SeedDatabaseGate.complete();

      const address = '0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8';
      const alias = 'my-collection.eth';
      final walletAddresses = [
        WalletAddress(
          address: address,
          name: alias,
          createdAt: DateTime.now().toUtc(),
        ),
      ];

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final databaseService = DatabaseService(db);

      final fakeAppState = _FakeAppStateForAliasTest(
        walletAddresses: walletAddresses,
        statuses: {
          address: AddressIndexingProcessStatus.idle(),
        },
      );

      final fakeIndexer = FakeIndexerServiceIsolate()
        ..pullStatusResult = const AddressIndexingJobResponse(
          workflowId: 'wf-1',
          address: address,
          status: IndexingJobStatus.completed,
          totalTokensIndexed: 0,
          totalTokensViewable: 0,
        );

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => databaseService),
          appStateServiceProvider.overrideWithValue(fakeAppState),
          indexerClientProvider.overrideWithValue(FakeIndexerClient()),
          domainAddressServiceProvider.overrideWithValue(
            DomainAddressService(resolverUrl: '', resolverApiKey: ''),
          ),
          indexerServiceIsolateProvider.overrideWithValue(fakeIndexer),
          bootstrapServiceProvider.overrideWith(
            (ref) => BootstrapService(
              databaseService: ref.read(databaseServiceProvider),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(ensureTrackedAddressesSyncCoordinatorProvider.notifier)
          .runSyncAndWait();

      final playlists = await databaseService.getAddressPlaylists();
      final playlist = playlists
          .where(
            (p) => p.ownerAddress?.toLowerCase() == address.toLowerCase(),
          )
          .firstOrNull;

      expect(playlist, isNotNull);
      expect(playlist!.name, alias);
    },
  );
}
