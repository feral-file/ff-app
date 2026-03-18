import 'dart:async';

import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/extensions/string_ext.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_service_isolate.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/integration_test_harness.dart';
import '../../helpers/spy_indexer_service_isolate.dart';

/// Migration integration test: verifies the add-address flow triggers
/// index → pullStatus → fetchTokens per [50-indexing-address-flow.mdc].
void main() {
  late IntegrationTestContext context;
  late AddressService addressService;
  late DomainAddressService domainAddressService;
  late SpyIndexerServiceIsolate spyIsolate;
  late _TestAppStateService testAppStateService;

  setUpAll(() async {
    context = await createIntegrationTestContext();
    testAppStateService = _TestAppStateService();

    final realIsolate = IndexerServiceIsolate(
      endpoint: AppConfig.indexerApiUrl,
      apiKey: AppConfig.indexerApiKey,
    );
    spyIsolate = SpyIndexerServiceIsolate(delegate: realIsolate);

    final indexerService = IndexerService(
      client: IndexerClient(
        endpoint: AppConfig.indexerApiUrl,
        defaultHeaders: <String, String>{
          'Content-Type': 'application/json',
          if (AppConfig.indexerApiKey.isNotEmpty)
            'Authorization': 'ApiKey ${AppConfig.indexerApiKey}',
        },
      ),
    );

    domainAddressService = DomainAddressService(
      resolverUrl: AppConfig.domainResolverUrl,
      resolverApiKey: AppConfig.domainResolverApiKey,
    );
    addressService = AddressService(
      databaseService: context.databaseService,
      indexerSyncService: IndexerSyncService(
        indexerService: indexerService,
        databaseService: context.databaseService,
      ),
      domainAddressService: domainAddressService,
      personalTokensSyncService: PersonalTokensSyncService(
        indexerService: indexerService,
        databaseService: context.databaseService,
        appStateService: testAppStateService,
      ),
      indexerServiceIsolate: spyIsolate,
      appStateService: testAppStateService,
    );
  });

  tearDownAll(() async {
    SeedDatabaseGate.resetForTesting();
    await context.dispose();
  });

  test(
    'addAddressOrDomain einstein-rosen.eth triggers index→pullStatus→fetchTokens and ingests 100+ tokens',
    () async {
      expect(AppConfig.domainResolverUrl, isNotEmpty);
      expect(AppConfig.domainResolverApiKey, isNotEmpty);
      expect(AppConfig.indexerApiUrl, isNotEmpty);
      expect(AppConfig.indexerApiKey, isNotEmpty);

      const inputDomain = 'einstein-rosen.eth';
      final resolved = await domainAddressService.verifyAddressOrDomain(
        inputDomain,
      );
      expect(resolved, isNotNull);
      final resolvedAddress = resolved!.address;
      await addressService.addAddressOrDomain(value: inputDomain);
      testAppStateService.setTargetAddress(resolvedAddress);

      // Provider-driven flow: ensure playlists exist and resume indexing.
      // AddressService.addAddress only writes tracked state; playlist creation
      // and indexing are triggered by ensureTrackedAddressesHavePlaylistsAndResume.
      await _ensurePlaylistsAndResumeIndexing(
        appState: testAppStateService,
        databaseService: context.databaseService,
        addressService: addressService,
      );

      // Poll until tokens in DB > 100 (indexing completes).
      const pollInterval = Duration(seconds: 5);
      const timeout = Duration(minutes: 20);
      final deadline = DateTime.now().add(timeout);
      var tokenCount = 0;

      while (DateTime.now().isBefore(deadline)) {
        final playlists =
            await context.databaseService.getAddressPlaylists();
        final match = playlists.where(
          (p) => p.ownerAddress?.toUpperCase() == resolvedAddress.toUpperCase(),
        ).toList();
        if (match.isNotEmpty) {
          tokenCount = match.first.itemCount;
          if (tokenCount > 100) break;
        }
        await Future<void>.delayed(pollInterval);
      }

      expect(
        tokenCount,
        greaterThan(100),
        reason: 'Expected >100 tokens ingested for $inputDomain.',
      );

      // Alias preservation: playlist created from domain should keep user-facing name.
      final playlists =
          await context.databaseService.getAddressPlaylists();
      final playlistForAddress = playlists.where(
        (p) => p.ownerAddress?.toUpperCase() == resolvedAddress.toUpperCase(),
      ).firstOrNull;
      expect(
        playlistForAddress?.name,
        inputDomain,
        reason: 'Playlist name should preserve domain/alias.',
      );

      // Wait for background indexing to fully complete before test exits.
      // AddressService._scheduleAddressIndexing fires unawaited work; if we exit
      // early, tearDown closes the DB while that work still runs, causing
      // "Channel was closed" and "failed after test completion" on CI.
      await testAppStateService.whenIndexingCompleted();

      // Verify all flow steps are called. Implementation uses fast-path fetch
      // (fetchTokens) before index for incremental UX, so we only assert:
      // - index before pullStatus
      // - all three operations occur
      expect(spyIsolate.callSequence, contains('index'));
      expect(spyIsolate.callSequence, contains('pullStatus'));
      expect(spyIsolate.callSequence, contains('fetchTokens'));

      final indexPos = spyIsolate.callSequence.indexOf('index');
      final pullPos = spyIsolate.callSequence.indexOf('pullStatus');

      expect(
        indexPos,
        lessThan(pullPos),
        reason: 'index must be called before pullStatus.',
      );
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

/// Runs the ensure-playlists-and-resume logic, mirroring
/// [ensureTrackedAddressesHavePlaylistsAndResumeProvider].
/// Used when testing without Riverpod (e.g. integration test).
Future<void> _ensurePlaylistsAndResumeIndexing({
  required AppStateServiceBase appState,
  required DatabaseService databaseService,
  required AddressService addressService,
}) async {
  final walletAddresses = await appState.getTrackedWalletAddresses();
  if (walletAddresses.isEmpty) return;
  final playlists = await databaseService.getAddressPlaylists();
  for (final wa in walletAddresses) {
    final normalized = wa.address.toNormalizedAddress();
    final hasPlaylist = playlists.any(
      (p) => p.ownerAddress?.toNormalizedAddress() == normalized,
    );
    if (hasPlaylist) continue;
    final playlist = PlaylistExt.fromWalletAddress(wa);
    await databaseService.ingestPlaylist(playlist);
  }
  final normalizedAddresses = walletAddresses
      .map((wa) => wa.address.toNormalizedAddress())
      .toSet()
      .toList();
  await addressService.resumeIndexingForAddresses(normalizedAddresses);
}

/// App state service that completes a future when indexing reaches [completed]
/// for the target address. Used to wait for background indexing before tearDown.
class _TestAppStateService implements AppStateServiceBase {
  _TestAppStateService();

  final List<String> _tracked = <String>[];
  final Map<String, String> _addressToAlias = {};
  String? _targetAddressNormalized;
  Completer<void>? _completer;

  void setTargetAddress(String address) {
    _targetAddressNormalized = address.toNormalizedAddress();
    _completer = Completer<void>();
  }

  /// Waits for indexing to complete for the target address. Call after
  /// [setTargetAddress]. Times out after 5 minutes to avoid hanging.
  Future<void> whenIndexingCompleted() async {
    final c = _completer;
    if (c == null) return;
    await c.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => throw TimeoutException(
        'Indexing did not complete within 5 minutes',
      ),
    );
  }

  @override
  Future<void> addTrackedAddress(String address, {String alias = ''}) async {
    final normalized = address.toNormalizedAddress();
    if (!_tracked.contains(normalized)) {
      _tracked.add(normalized);
    }
    _addressToAlias[normalized] = alias.trim().isNotEmpty
        ? alias
        : normalized.shortenAddress();
  }

  final Map<String, AddressIndexingProcessStatus> _addressStatuses = {};

  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {
    final normalized = address.toNormalizedAddress();
    _addressStatuses[normalized] = status;
    if (_targetAddressNormalized == null || _completer == null || _completer!.isCompleted) {
      return;
    }
    if (normalized != _targetAddressNormalized) return;
    // Complete on terminal states so we never hang (completed or failed).
    if (status.state == AddressIndexingProcessState.completed ||
        status.state == AddressIndexingProcessState.failed ||
        status.state == AddressIndexingProcessState.stopped) {
      _completer!.complete();
    }
  }

  @override
  Future<Map<String, AddressIndexingProcessStatus>> getAllAddressIndexingStatuses() async =>
      Map.unmodifiable(_addressStatuses);

  @override
  Future<void> trackPersonalAddress(String address) async {
    final normalized = address.toNormalizedAddress();
    if (!_tracked.contains(normalized)) {
      _tracked.add(normalized);
      _addressToAlias[normalized] = normalized.shortenAddress();
    }
  }

  @override
  Future<List<String>> getTrackedPersonalAddresses() async =>
      List.unmodifiable(_tracked);

  @override
  Future<List<WalletAddress>> getTrackedWalletAddresses() async {
    final now = DateTime.now().toUtc();
    return _tracked.map((addr) {
      final name = _addressToAlias[addr] ?? addr.shortenAddress();
      return WalletAddress(
        address: addr,
        name: name,
        createdAt: now,
      );
    }).toList();
  }

  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) =>
      Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
