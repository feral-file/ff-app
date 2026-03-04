import 'dart:io';

import 'package:app/domain/models/models.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:app/infra/services/pending_addresses_store.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/integration_env.dart';
import '../../helpers/integration_test_harness.dart';

class _SeedDatabaseServiceForImportTest extends SeedDatabaseService {
  _SeedDatabaseServiceForImportTest({
    required this.databasePathOverride,
    required super.temporaryDirectoryProvider,
  });

  final String databasePathOverride;

  @override
  Future<String> databasePath() async => databasePathOverride;
}

class _FakePendingAddressesStore extends PendingAddressesStore {
  @override
  Future<List<String>> getAddresses() async => const <String>[];
}

class _FakeAppStateService implements AppStateServiceBase {
  final List<String> tracked = <String>[];

  @override
  Future<void> trackPersonalAddress(String address) async {
    tracked.add(address);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingPersonalTokensSyncService extends PersonalTokensSyncService {
  _RecordingPersonalTokensSyncService({
    required _FakeAppStateService appState,
    required super.databaseService,
  }) : super(
         indexerService: IndexerService(
           client: IndexerClient(endpoint: 'https://example.invalid/graphql'),
         ),
         appStateService: appState,
       );

  final List<String> syncedAddresses = <String>[];

  @override
  Future<void> syncAddresses({required List<String> addresses}) async {
    syncedAddresses.addAll(addresses);
  }
}

const String _skipReason =
    'S3 seed integration requires S3_BUCKET, S3_ACCESS_KEY_ID, '
    'S3_SECRET_ACCESS_KEY, S3_REGION, and S3_SEED_DATABASE_OBJECT_KEY in .env.';

void main() {
  final env = loadRootEnvValues();
  final skipSeedFlow = !hasValidS3SeedConfig(env);

  group('Seed and personal-address flow', () {
    late File provisionedEnvFile;

    setUpAll(() async {
      if (skipSeedFlow) return;
      provisionedEnvFile = await provisionIntegrationEnvFile();
    });

    tearDownAll(() async {
      if (skipSeedFlow) return;
      final parent = provisionedEnvFile.parent;
      if (parent.existsSync()) {
        await parent.delete(recursive: true);
      }
    });

    test(
      'downloads and imports seed database, then persists a personal address',
      skip: skipSeedFlow ? _skipReason : null,
      () async {
        final tempDir = await Directory.systemTemp.createTemp('ff_seed_flow_');
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });

        final importPath = '${tempDir.path}/playlist_cache.sqlite';
        final seedService = _SeedDatabaseServiceForImportTest(
          databasePathOverride: importPath,
          temporaryDirectoryProvider: () async => tempDir,
        );

        final downloadedPath = await seedService.downloadToTemporaryFile();
        await seedService.replaceDatabaseFromTemporaryFile(downloadedPath);

        final importedSeedFile = File(importPath);
        expect(importedSeedFile.existsSync(), isTrue);
        expect(await importedSeedFile.length(), greaterThan(0));

        SeedDatabaseGate.complete();
        final context = await createIntegrationTestContext();
        addTearDown(context.dispose);

        final appState = _FakeAppStateService();
        final personalTokensSyncService = _RecordingPersonalTokensSyncService(
          appState: appState,
          databaseService: context.databaseService,
        );

        final addressService = AddressService(
          databaseService: context.databaseService,
          indexerSyncService: IndexerSyncService(
            indexerService: IndexerService(
              client: IndexerClient(
                endpoint: 'https://example.invalid/graphql',
              ),
            ),
            databaseService: context.databaseService,
          ),
          domainAddressService: DomainAddressService(
            resolverUrl: '',
            resolverApiKey: '',
          ),
          personalTokensSyncService: personalTokensSyncService,
          pendingAddressesStore: _FakePendingAddressesStore(),
        );

        const addressValue = '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8';
        final walletAddress = WalletAddress(
          address: addressValue,
          name: 'Integration Address',
          createdAt: DateTime.now(),
        );

        final playlist = await addressService.addAddress(
          walletAddress: walletAddress,
          syncNow: false,
        );

        expect(playlist.ownerAddress, equals(addressValue));
        expect(appState.tracked, contains(addressValue));
        expect(personalTokensSyncService.syncedAddresses, isEmpty);

        final playlists = await context.databaseService.getAddressPlaylists();
        expect(
          playlists.any((it) => it.ownerAddress == addressValue),
          isTrue,
        );
      },
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });
}
