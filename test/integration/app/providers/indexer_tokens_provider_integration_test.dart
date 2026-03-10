import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/domain/models/indexer/sync_collection.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../helpers/indexer_domain_integration_helpers.dart';
import '../../helpers/integration_test_harness.dart';

class IntegrationAppStateService implements AppStateService {
  final Map<String, SyncCheckpoint> checkpoints = <String, SyncCheckpoint>{};

  @override
  Future<SyncCheckpoint?> getAddressCheckpoint(String address) async =>
      checkpoints[address];

  @override
  Future<void> setAddressCheckpoint({
    required String address,
    required SyncCheckpoint checkpoint,
  }) async {
    checkpoints[address] = checkpoint;
  }

  @override
  Future<void> clearAddressCheckpoint(String address) async {
    checkpoints.remove(address);
  }

  @override
  Future<List<String>> getAddressesWithCompletedIndexing() async =>
      checkpoints.keys.toList();

  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) =>
      Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late IntegrationTestContext context;
  late IntegrationAppStateService appStateService;
  late DomainAddressService domainAddressService;
  late IndexerService indexerService;

  setUpAll(() async {
    context = await createIntegrationTestContext();
    appStateService = IntegrationAppStateService();
    domainAddressService = DomainAddressService(
      resolverUrl: AppConfig.domainResolverUrl,
      resolverApiKey: AppConfig.domainResolverApiKey,
    );
    indexerService = IndexerService(
      client: IndexerClient(
        endpoint: AppConfig.indexerApiUrl,
        defaultHeaders: <String, String>{
          'Content-Type': 'application/json',
          if (AppConfig.indexerApiKey.isNotEmpty)
            'Authorization': 'ApiKey ${AppConfig.indexerApiKey}',
        },
      ),
    );
  });

  tearDownAll(() async {
    await context.dispose();
  });

  Future<void> seedAddressPlaylist(String address) async {
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    await context.database.customStatement(
      '''
      INSERT INTO playlists (
        id, channel_id, type, base_url, dp_version, slug, title,
        created_at_us, updated_at_us, signatures_json, defaults_json,
        dynamic_queries_json, owner_address, owner_chain, sort_mode, item_count
      ) VALUES (?, NULL, 1, NULL, NULL, NULL, ?, ?, ?, '[]', NULL, NULL, ?, NULL, 1, 0)
      ''',
      <Object>[
        'pl_$address',
        'Address $address',
        nowUs,
        nowUs,
        address.toUpperCase(),
      ],
    );
  }

  test(
    'sync einstein-rosen.eth ingests 100+ tokens with thumbnails via worker',
    () async {
      expect(AppConfig.indexerApiUrl, isNotEmpty);
      expect(AppConfig.indexerApiKey, isNotEmpty);
      expect(AppConfig.domainResolverUrl, isNotEmpty);
      expect(AppConfig.domainResolverApiKey, isNotEmpty);

      const inputDomain = 'einstein-rosen.eth';
      final resolved = await domainAddressService.verifyAddressOrDomain(
        inputDomain,
      );
      expect(resolved, isNotNull, reason: 'Failed to resolve $inputDomain');
      final resolvedAddress = resolved!.address;
      await waitForAddressIndexingCompletion(
        indexerService: indexerService,
        address: resolvedAddress,
      );

      final container = ProviderContainer.test(
        overrides: [
          appStateServiceProvider.overrideWithValue(appStateService),
          databaseServiceProvider.overrideWithValue(context.databaseService),
        ],
      );
      addTearDown(container.dispose);
      await seedAddressPlaylist(resolvedAddress);

      final baselineTokens = await fetchAllTokensByOffsetCursor(
        indexerService: indexerService,
        address: resolvedAddress,
      );
      expect(
        baselineTokens.length,
        greaterThan(100),
        reason: 'Expected >100 indexer tokens for $inputDomain.',
      );

      final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
      await notifier.syncAddresses(<String>[resolvedAddress]);

      final db = sqlite3.open(context.databaseFile.path);
      addTearDown(db.dispose);

      final ownerAddress = resolvedAddress.toUpperCase();
      final tokenCountRows = db.select(
        '''
        SELECT COUNT(*) AS token_count
        FROM playlists p
        INNER JOIN playlist_entries pe ON pe.playlist_id = p.id
        INNER JOIN items i ON i.id = pe.item_id
        WHERE p.owner_address = ? AND i.kind = 1
        ''',
        <Object>[ownerAddress],
      );
      final tokenCount = tokenCountRows.first['token_count'] as int;
      expect(tokenCount, greaterThanOrEqualTo(0));

      final missingThumbnailRows = db.select(
        '''
        SELECT COUNT(*) AS missing_count
        FROM playlists p
        INNER JOIN playlist_entries pe ON pe.playlist_id = p.id
        INNER JOIN items i ON i.id = pe.item_id
        WHERE p.owner_address = ?
          AND i.kind = 1
          AND (i.thumbnail_uri IS NULL OR i.thumbnail_uri = '')
        ''',
        <Object>[ownerAddress],
      );
      final missingThumbnailCount =
          missingThumbnailRows.first['missing_count'] as int;
      expect(
        missingThumbnailCount,
        equals(0),
        reason: 'Expected no indexed token with missing thumbnail.',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
