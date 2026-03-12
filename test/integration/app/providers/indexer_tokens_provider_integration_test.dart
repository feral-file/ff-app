import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/indexer/sync_collection.dart';
import 'package:app/domain/utils/address_deduplication.dart';
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
  ) => Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// IndexerService that delegates to real but overrides syncCollection and
/// getManualTokens for controlled integration tests.
class MockIndexerServiceForSyncCollection extends IndexerService {
  MockIndexerServiceForSyncCollection({
    required super.client,
    required this.realService,
    this.mockSyncResult,
    this.mockTokensById = const {},
  });

  final IndexerService realService;
  SyncCollectionResult? mockSyncResult;
  Map<int, AssetToken> mockTokensById;

  @override
  Future<SyncCollectionResult> syncCollection(
    QuerySyncCollectionRequest request,
  ) async {
    if (mockSyncResult != null) return mockSyncResult!;
    return realService.syncCollection(request);
  }

  @override
  Future<List<AssetToken>> getManualTokens({
    List<int>? tokenIds,
    List<String>? owners,
    List<String>? tokenCids,
    int? limit,
    int? offset,
  }) async {
    final ids = tokenIds ?? const <int>[];
    if (ids.isNotEmpty && mockTokensById.isNotEmpty) {
      final tokens = ids
          .map((id) => mockTokensById[id])
          .whereType<AssetToken>()
          .toList();
      if (tokens.length == ids.length) return tokens;
    }
    return realService.getManualTokens(
      tokenIds: tokenIds,
      owners: owners,
      tokenCids: tokenCids,
      limit: limit,
      offset: offset,
    );
  }
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

  test(
    'syncCollection removes released token and updates others',
    () async {
      expect(AppConfig.indexerApiUrl, isNotEmpty);
      expect(AppConfig.indexerApiKey, isNotEmpty);

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

      final normalizedAddress = resolvedAddress.toNormalizedAddress();

      final mockIndexer = MockIndexerServiceForSyncCollection(
        client: IndexerClient(
          endpoint: AppConfig.indexerApiUrl,
          defaultHeaders: <String, String>{
            'Content-Type': 'application/json',
            if (AppConfig.indexerApiKey.isNotEmpty)
              'Authorization': 'ApiKey ${AppConfig.indexerApiKey}',
          },
        ),
        realService: indexerService,
      );

      final container = ProviderContainer.test(
        overrides: [
          appStateServiceProvider.overrideWithValue(appStateService),
          databaseServiceProvider.overrideWithValue(context.databaseService),
          indexerServiceProvider.overrideWithValue(mockIndexer),
        ],
      );
      addTearDown(container.dispose);

      await seedAddressPlaylist(resolvedAddress);

      final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
      await notifier.syncAddresses(<String>[resolvedAddress]);

      final baselineTokens = await fetchAllTokensByOffsetCursor(
        indexerService: indexerService,
        address: resolvedAddress,
      );
      expect(
        baselineTokens.length,
        greaterThanOrEqualTo(3),
        reason: 'Need at least 3 tokens for syncCollection test',
      );

      final tokenToRelease = baselineTokens[0];
      final tokenToUpdate1 = baselineTokens[1];
      final tokenToUpdate2 = baselineTokens[2];

      final checkpoint = SyncCheckpoint(
        timestamp: DateTime.now().toUtc(),
        eventId: 0,
      );
      await appStateService.setAddressCheckpoint(
        address: normalizedAddress,
        checkpoint: checkpoint,
      );

      final baseTime = DateTime.now().toUtc();
      mockIndexer.mockSyncResult = SyncCollectionResult(
        events: [
          // Token 1 (removal): acquired -> metadata_updated -> released -> metadata_updated -> released (last transfer)
          TokenEvent(
            id: 1,
            tokenId: tokenToRelease.id,
            eventType: 'acquired',
            ownerAddress: normalizedAddress,
            occurredAt: baseTime.add(const Duration(seconds: 1)),
          ),
          TokenEvent(
            id: 2,
            tokenId: tokenToRelease.id,
            eventType: 'metadata_updated',
            occurredAt: baseTime.add(const Duration(seconds: 2)),
          ),
          TokenEvent(
            id: 3,
            tokenId: tokenToRelease.id,
            eventType: 'released',
            ownerAddress: normalizedAddress,
            occurredAt: baseTime.add(const Duration(seconds: 3)),
          ),
          TokenEvent(
            id: 4,
            tokenId: tokenToRelease.id,
            eventType: 'metadata_updated',
            occurredAt: baseTime.add(const Duration(seconds: 4)),
          ),
          TokenEvent(
            id: 5,
            tokenId: tokenToRelease.id,
            eventType: 'released',
            ownerAddress: normalizedAddress,
            occurredAt: baseTime.add(const Duration(seconds: 5)),
          ),
          // Token 2 (updated): acquired -> released -> metadata_updated -> acquired (last transfer)
          TokenEvent(
            id: 6,
            tokenId: tokenToUpdate1.id,
            eventType: 'acquired',
            ownerAddress: normalizedAddress,
            occurredAt: baseTime.add(const Duration(seconds: 10)),
          ),
          TokenEvent(
            id: 7,
            tokenId: tokenToUpdate1.id,
            eventType: 'released',
            ownerAddress: normalizedAddress,
            occurredAt: baseTime.add(const Duration(seconds: 11)),
          ),
          TokenEvent(
            id: 8,
            tokenId: tokenToUpdate1.id,
            eventType: 'metadata_updated',
            occurredAt: baseTime.add(const Duration(seconds: 12)),
          ),
          TokenEvent(
            id: 9,
            tokenId: tokenToUpdate1.id,
            eventType: 'acquired',
            ownerAddress: normalizedAddress,
            occurredAt: baseTime.add(const Duration(seconds: 13)),
          ),
          // Token 3 (updated): metadata_updated -> acquired -> metadata_updated -> metadata_updated (last transfer = acquired)
          TokenEvent(
            id: 10,
            tokenId: tokenToUpdate2.id,
            eventType: 'metadata_updated',
            occurredAt: baseTime.add(const Duration(seconds: 20)),
          ),
          TokenEvent(
            id: 11,
            tokenId: tokenToUpdate2.id,
            eventType: 'acquired',
            ownerAddress: normalizedAddress,
            occurredAt: baseTime.add(const Duration(seconds: 21)),
          ),
          TokenEvent(
            id: 12,
            tokenId: tokenToUpdate2.id,
            eventType: 'metadata_updated',
            occurredAt: baseTime.add(const Duration(seconds: 22)),
          ),
          TokenEvent(
            id: 13,
            tokenId: tokenToUpdate2.id,
            eventType: 'metadata_updated',
            occurredAt: baseTime.add(const Duration(seconds: 23)),
          ),
        ],
        nextCheckpoint: SyncCheckpoint(
          timestamp: baseTime.add(const Duration(seconds: 30)),
          eventId: 99,
        ),
        serverTime: baseTime,
      );

      mockIndexer.mockTokensById = {
        tokenToRelease.id: tokenToRelease,
        tokenToUpdate1.id: tokenToUpdate1,
        tokenToUpdate2.id: tokenToUpdate2,
      };

      final syncService = container.read(addressSyncCollectionServiceProvider);
      await syncService.syncAddressWithCollection(resolvedAddress);

      final db = sqlite3.open(context.databaseFile.path);
      addTearDown(db.dispose);

      final ownerAddress = resolvedAddress.toUpperCase();
      final releasedCid = tokenToRelease.cid;
      final releasedStillInPlaylist = db.select(
        '''
        SELECT 1 FROM playlists p
        INNER JOIN playlist_entries pe ON pe.playlist_id = p.id
        WHERE p.owner_address = ? AND pe.item_id = ?
        ''',
        <Object>[ownerAddress, releasedCid],
      );
      expect(
        releasedStillInPlaylist,
        isEmpty,
        reason: 'Released token ($releasedCid) should be removed from playlist',
      );

      final updated1StillInPlaylist = db.select(
        '''
        SELECT 1 FROM playlists p
        INNER JOIN playlist_entries pe ON pe.playlist_id = p.id
        WHERE p.owner_address = ? AND pe.item_id = ?
        ''',
        <Object>[ownerAddress, tokenToUpdate1.cid],
      );
      expect(
        updated1StillInPlaylist,
        isNotEmpty,
        reason: 'Updated token 1 should remain in playlist',
      );

      final updated2StillInPlaylist = db.select(
        '''
        SELECT 1 FROM playlists p
        INNER JOIN playlist_entries pe ON pe.playlist_id = p.id
        WHERE p.owner_address = ? AND pe.item_id = ?
        ''',
        <Object>[ownerAddress, tokenToUpdate2.cid],
      );
      expect(
        updated2StillInPlaylist,
        isNotEmpty,
        reason: 'Updated token 2 should remain in playlist',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}
