import 'dart:async';
import 'dart:math';

import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service_isolate.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:app/infra/services/pending_addresses_store.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:logging/logging.dart';

/// Service for managing user wallet addresses and address-based playlists.
class AddressService {
  /// Creates an AddressService.
  AddressService({
    required DatabaseService databaseService,
    required IndexerSyncService indexerSyncService,
    required DomainAddressService domainAddressService,
    required PersonalTokensSyncService personalTokensSyncService,
    required PendingAddressesStore pendingAddressesStore,
    required IndexerServiceIsolateOperations indexerServiceIsolate,
    required AppStateServiceBase appStateService,
  }) : _databaseService = databaseService,
       _domainAddressService = domainAddressService,
       _personalTokensSyncService = personalTokensSyncService,
       _pendingAddressesStore = pendingAddressesStore,
       _indexerServiceIsolate = indexerServiceIsolate,
       _appStateService = appStateService {
    _indexerSyncService = indexerSyncService;
    _log = Logger('AddressService');
  }

  final DatabaseService _databaseService;
  final DomainAddressService _domainAddressService;
  final PersonalTokensSyncService _personalTokensSyncService;
  final PendingAddressesStore _pendingAddressesStore;
  final IndexerServiceIsolateOperations _indexerServiceIsolate;
  final AppStateServiceBase _appStateService;
  late final IndexerSyncService _indexerSyncService;
  late final Logger _log;

  void Function(AddressIndexingJobResponse)? _onIndexingJobStatusCallback;

  /// Sets a callback that receives real-time indexer job status updates.
  ///
  /// The callback is invoked when [pullStatus] returns during [indexAndSyncAddress].
  void setIndexingJobStatusCallback(
    void Function(AddressIndexingJobResponse) callback,
  ) {
    _onIndexingJobStatusCallback = callback;
  }

  /// Triggers indexing for an address. Returns workflowId or null.
  Future<String?> index(String address) async {
    final results = await _indexerServiceIsolate.indexAddressesList([address]);
    for (final r in results) {
      if (_addressesEqual(r.address, address)) return r.workflowId;
    }
    return null;
  }

  /// Polls job status by workflowId.
  Future<AddressIndexingJobResponse> pullStatus(String workflowId) async {
    return _indexerServiceIsolate.getAddressIndexingJobStatus(workflowId);
  }

  /// Fetches token pages for address and ingests into DB.
  ///
  /// Paginates from [startOffset] until no more tokens. Returns total ingested.
  Future<int> syncTokens(String address, {int startOffset = 0}) async {
    const pageSize = 50;
    var offset = startOffset;
    var total = 0;
    while (true) {
      final page = await _indexerServiceIsolate.fetchTokensPageByAddresses(
        addresses: [address],
        limit: pageSize,
        offset: offset,
      );
      if (page.tokens.isEmpty) return total;
      await _databaseService.ingestTokensForAddress(
        address: address,
        tokens: page.tokens,
      );
      final count = page.tokens.length;
      total += count;
      offset += count;
      if (count < pageSize) break;
    }
    return total;
  }

  /// Runs indexing flow: index → poll → fetch+ingest.
  ///
  /// Single flow. Each step has a flag — set to false when that step was
  /// already done (e.g. on app restart). Pass [workflowId] when [runTriggerIndex]
  /// is false and [runPoll] is true.
  ///
  /// Steps: (1) fast-path fetch, (2) trigger index, (3) poll until done,
  /// (4) final fetch+ingest.
  Future<void> indexAndSyncAddress(
    String address, {
    bool runFastPathFetch = true,
    bool runTriggerIndex = true,
    bool runPoll = true,
    bool runFinalFetch = true,
    String? workflowId,
  }) async {
    final queryAddress = _addressForIndexer(address);
    var effectiveWorkflowId = workflowId;

    // Step 1: Fast-path fetch
    if (runFastPathFetch) {
      unawaited(syncTokens(queryAddress));
    }

    // Step 2: Trigger indexing
    if (runTriggerIndex) {
      try {
        final id = await index(queryAddress);
        if (id == null || id.isEmpty) {
          await _appStateService.setAddressIndexingStatus(
            address: queryAddress,
            status: AddressIndexingProcessStatus.failed(),
          );
          throw Exception('Failed to trigger indexing');
        }
        effectiveWorkflowId = id;
      } catch (e, stack) {
        await _appStateService.setAddressIndexingStatus(
          address: queryAddress,
          status: AddressIndexingProcessStatus.failed(),
        );
        Error.throwWithStackTrace(e, stack);
      }

      await _appStateService.setAddressIndexingStatus(
        address: queryAddress,
        status: AddressIndexingProcessStatus.indexingTriggered(
          workflowId: effectiveWorkflowId,
        ),
      );
    }

    if (runPoll &&
        (effectiveWorkflowId == null || effectiveWorkflowId.isEmpty)) {
      await _appStateService.setAddressIndexingStatus(
        address: queryAddress,
        status: AddressIndexingProcessStatus.failed(),
      );
      throw Exception(
        'workflowId required when runTriggerIndex is false and runPoll is true',
      );
    }

    // Step 3: Poll until done
    if (runPoll) {
      final wfId = effectiveWorkflowId!;
      const pollInterval = Duration(seconds: 15);
      const maxAttempts = 60;

      await _appStateService.setAddressIndexingStatus(
        address: queryAddress,
        status: AddressIndexingProcessStatus.waitingForIndexStatus(),
      );

      for (var attempt = 0; attempt < maxAttempts; attempt++) {
        AddressIndexingJobResponse status;
        try {
          status = await pullStatus(wfId);
        } catch (e, stack) {
          await _appStateService.setAddressIndexingStatus(
            address: queryAddress,
            status: AddressIndexingProcessStatus.failed(),
          );
          Error.throwWithStackTrace(e, stack);
        }

        _onIndexingJobStatusCallback?.call(status);

        if (status.status.isDone) {
          if (status.status.isFailed) {
            await _appStateService.setAddressIndexingStatus(
              address: queryAddress,
              status: AddressIndexingProcessStatus.failed(),
            );
            throw Exception(
              'Indexing failed with status: ${status.status.name}',
            );
          }
          break;
        }

        try {
          unawaited(syncTokens(queryAddress));
        } on Object {
          // Ignore fetch errors during poll; will retry next poll.
        }

        await Future<void>.delayed(pollInterval);
      }
    }

    // Step 4: Final fetch+ingest
    if (runFinalFetch) {
      await _appStateService.setAddressIndexingStatus(
        address: queryAddress,
        status: AddressIndexingProcessStatus.syncingTokens(),
      );
      await syncTokens(queryAddress);
      await _appStateService.setAddressIndexingStatus(
        address: queryAddress,
        status: AddressIndexingProcessStatus.completed(),
      );
    }

    _log.info('IndexAndSync completed for $queryAddress');
  }

  /// Resumes pending indexing flows for addresses with non-completed status.
  ///
  /// Called at app startup. For each address: await 100–500 ms random delay
  /// to avoid doing a lot of work at the same time, then fire-and-forget
  /// the resume. Runs sequentially per address.
  Future<void> resumePendingIndexingFlows() async {
    final playlists = await getAddressPlaylists();
    final addresses = playlists
        .map((p) => p.ownerAddress)
        .whereType<String>()
        .map((a) => a.toNormalizedAddress())
        .toSet()
        .toList(growable: false);

    if (addresses.isEmpty) return;

    final statuses = await _appStateService.getAllAddressIndexingStatuses();
    final toResume = addresses
        .where((addr) {
          final status = statuses[addr];
          return status != null &&
              status.state != AddressIndexingProcessState.completed;
        })
        .toList(growable: false);

    if (toResume.isEmpty) return;

    _log.info('Resuming ${toResume.length} pending indexing flow(s)');

    final random = Random();

    for (final address in toResume) {
      await Future<void>.delayed(
        Duration(milliseconds: 100 + random.nextInt(401)),
      );

      final status = statuses[address];
      if (status == null) continue;

      unawaited(
        _runResumeForAddress(address, status).catchError(
          (Object error, StackTrace stack) {
            _log.warning(
              'Resume indexing failed for $address',
              error,
              stack,
            );
          },
        ),
      );
    }
  }

  Future<void> _runResumeForAddress(
    String address,
    AddressIndexingProcessStatus status,
  ) async {
    switch (status.state) {
      case AddressIndexingProcessState.idle:
      case AddressIndexingProcessState.failed:
      case AddressIndexingProcessState.stopped:
        _scheduleAddressIndexing(address);
      case AddressIndexingProcessState.indexingTriggered:
      case AddressIndexingProcessState.waitingForIndexStatus:
      case AddressIndexingProcessState.paused:
        final wfId = status.workflowId;
        if (wfId != null && wfId.isNotEmpty) {
          await indexAndSyncAddress(
            address,
            runFastPathFetch: false,
            runTriggerIndex: false,
            workflowId: wfId,
          );
        } else {
          _scheduleAddressIndexing(address);
        }
      case AddressIndexingProcessState.syncingTokens:
        await indexAndSyncAddress(
          address,
          runFastPathFetch: false,
          runTriggerIndex: false,
          runPoll: false,
        );
      case AddressIndexingProcessState.completed:
        break;
    }
  }

  String _addressForIndexer(String address) => address.toNormalizedAddress();

  /// Add an address from either a raw address or ENS/TNS domain.
  Future<Playlist> addAddressOrDomain({
    required String value,
    String channelId = Channel.myCollectionId,
  }) async {
    final resolved = await _domainAddressService.verifyAddressOrDomain(value);
    if (resolved == null) {
      throw Exception('Invalid address or unsupported ENS/TNS domain: $value');
    }

    final walletAddress = WalletAddress(
      address: resolved.address,
      createdAt: DateTime.now(),
      name: resolved.domain ?? _shortenAddress(resolved.address),
    );

    return addAddress(walletAddress: walletAddress, channelId: channelId);
  }

  /// Add a wallet address and create its playlist.
  ///
  /// If the `SeedDatabaseGate` is not yet open (i.e. the seed database is
  /// still downloading on a fresh install), the address is stored in
  /// `PendingAddressesStore` and no SQLite write is attempted.
  /// `_AppStartupBootstrap` will migrate pending addresses into SQLite and
  /// start the workers once the database gate opens.
  ///
  /// When [fromPendingMigration] is true, the address was already added via
  /// the pending path (tracked + idle status set). Skip redundant state updates
  /// to avoid duplicate idle logs and emissions.
  Future<Playlist> addAddress({
    required WalletAddress walletAddress,
    String channelId = Channel.myCollectionId,
    bool syncNow = true,
    bool fromPendingMigration = false,
  }) async {
    try {
      final chain = walletAddress.chain;
      final normalizedAddress = walletAddress.address.toNormalizedAddress();
      _log.info('Adding address: $normalizedAddress on chain $chain');

      if (!SeedDatabaseGate.isCompleted) {
        // DB not ready yet: persist the address in the pending store so it
        // survives navigation and is migrated to SQLite after the seed lands.
        await _pendingAddressesStore.addAddress(normalizedAddress);
        await _appStateService.addTrackedAddress(
          normalizedAddress,
          alias: walletAddress.name,
        );
        await _appStateService.setAddressIndexingStatus(
          address: normalizedAddress,
          status: AddressIndexingProcessStatus.idle(),
        );
        // Do NOT call _scheduleAddressIndexing here: the playlist does not
        // exist in Drift yet. ingestTokensForAddress requires the playlist to
        // exist and would skip ingestion otherwise. _migratePendingAddresses
        // will create the playlist and call _scheduleAddressIndexing once the
        // seed is ready.
        if (!syncNow) {
          await _personalTokensSyncService.trackAddress(normalizedAddress);
        }
        _log.info(
          'Database not ready – address queued for post-seed migration: '
          '$normalizedAddress',
        );
        return PlaylistExt.fromWalletAddress(
          walletAddress,
          channelId: channelId,
        );
      }

      final existing = await _getAddressPlaylistByOwner(normalizedAddress);
      if (existing != null) {
        _log.info('Address playlist already exists: ${existing.id}');
        if (syncNow) {
          _scheduleAddressIndexing(normalizedAddress);
        } else {
          await _personalTokensSyncService.trackAddress(normalizedAddress);
        }
        return existing;
      }

      final playlist = PlaylistExt.fromWalletAddress(
        walletAddress,
        channelId: channelId,
      );

      await _databaseService.ingestPlaylist(playlist);
      if (!fromPendingMigration) {
        await _appStateService.addTrackedAddress(
          normalizedAddress,
          alias: walletAddress.name,
        );
        await _appStateService.setAddressIndexingStatus(
          address: normalizedAddress,
          status: AddressIndexingProcessStatus.idle(),
        );
      }
      if (syncNow) {
        _scheduleAddressIndexing(normalizedAddress);
      } else {
        await _personalTokensSyncService.trackAddress(normalizedAddress);
      }

      _log.info('Added address playlist: ${playlist.id}');
      return playlist;
    } catch (e, stack) {
      _log.severe('Failed to add address $walletAddress', e, stack);
      rethrow;
    }
  }

  /// Returns true when the address has already been added.
  ///
  /// This checks both:
  /// - pending addresses (when the seed DB gate is not open yet)
  /// - persisted address-based playlists in SQLite (normal runtime)
  Future<bool> isAddressAlreadyAdded({
    required String address,
    required Chain chain,
  }) async {
    final normalizedInput = address.normalizeForComparison(chain: chain);

    if (!SeedDatabaseGate.isCompleted) {
      final pending = await _pendingAddressesStore.getAddresses();
      return pending.any(
        (value) =>
            value.normalizeForComparison(chain: chain) == normalizedInput,
      );
    }

    final playlists = await _databaseService.getAddressPlaylists();
    for (final playlist in playlists) {
      final owner = playlist.ownerAddress;
      if (owner == null) continue;
      if (owner.normalizeForComparison(chain: chain) == normalizedInput) {
        return true;
      }
    }
    return false;
  }

  void _scheduleAddressIndexing(String normalizedAddress) {
    unawaited(
      _personalTokensSyncService
          .trackAddress(normalizedAddress)
          .then((_) => indexAndSyncAddress(normalizedAddress))
          .catchError((
            Object error,
            StackTrace stack,
          ) {
            _log.warning(
              'Background indexing schedule failed for $normalizedAddress',
              error,
              stack,
            );
          }),
    );
  }

  /// Remove an address and its playlist.
  ///
  /// If [playlistId] is provided, uses it; otherwise derives it from the
  /// normalized address via [PlaylistExt.addressPlaylistId].
  Future<void> removeAddress({
    required WalletAddress walletAddress,
    String? playlistId,
  }) async {
    try {
      final normalizedAddress = walletAddress.address.toNormalizedAddress();
      final resolvedPlaylistId =
          playlistId ?? PlaylistExt.addressPlaylistId(normalizedAddress);

      _log.info('Removing address: $normalizedAddress');
      await _personalTokensSyncService.untrackAddress(normalizedAddress);

      final playlist = await _databaseService.getPlaylistById(resolvedPlaylistId);
      if (playlist == null) {
        _log.warning('Address playlist not found: $resolvedPlaylistId');
        return;
      }

      await _databaseService.deleteItemsOfAddresses([normalizedAddress]);
      await _databaseService.deletePlaylist(
        resolvedPlaylistId,
        skipEntries: true,
      );

      await _appStateService.clearAddressState(normalizedAddress);

      _log.info('Removed address playlist: $resolvedPlaylistId');
    } catch (e, stack) {
      _log.severe('Failed to remove address $walletAddress', e, stack);
      rethrow;
    }
  }

  /// Refresh tokens for an address.
  /// Fetches latest tokens from indexer and updates the database.
  Future<int> refreshAddress({
    required String address,
  }) async {
    try {
      final normalizedAddress = address.toNormalizedAddress();
      _log.info('Refreshing tokens for address: $normalizedAddress');

      final count = await _indexerSyncService.syncTokensForAddresses(
        addresses: [normalizedAddress],
      );

      _log.info('Refreshed $count tokens for address $normalizedAddress');
      return count;
    } catch (e, stack) {
      _log.severe('Failed to refresh address $address', e, stack);
      rethrow;
    }
  }

  /// Refresh all addresses.
  Future<int> refreshAllAddresses() async {
    try {
      _log.info('Refreshing all addresses');

      final playlists = await _databaseService.getAddressPlaylists();
      final addresses = playlists
          .map((p) => p.ownerAddress)
          .where((a) => a != null)
          .cast<String>()
          .toList();

      if (addresses.isEmpty) {
        _log.info('No addresses to refresh');
        return 0;
      }

      final count = await _indexerSyncService.syncTokensForAddresses(
        addresses: addresses,
      );

      _log.info('Refreshed $count tokens for ${addresses.length} addresses');
      return count;
    } catch (e, stack) {
      _log.severe('Failed to refresh all addresses', e, stack);
      rethrow;
    }
  }

  /// Get all address playlists.
  Future<List<Playlist>> getAddressPlaylists() async {
    return _databaseService.getAddressPlaylists();
  }

  /// Get all owner addresses from the database (from address-based playlists).
  ///
  /// Used by work detail and other features that need the list of user
  /// addresses.
  Future<List<String>> getAllAddresses() async {
    final playlists = await _databaseService.getAddressPlaylists();
    return playlists.map((p) => p.ownerAddress).whereType<String>().toList();
  }

  Future<Playlist?> _getAddressPlaylistByOwner(String normalizedAddress) async {
    final playlists = await _databaseService.getAddressPlaylists();
    for (final playlist in playlists) {
      final owner = playlist.ownerAddress;
      if (owner == null) {
        continue;
      }
      if (_addressesEqual(owner, normalizedAddress)) {
        return playlist;
      }
    }
    return null;
  }

  bool _addressesEqual(String left, String right) =>
      left.toNormalizedAddress() == right.toNormalizedAddress();

  /// Shorten address for display (0x1234...5678).
  String _shortenAddress(String address) {
    if (address.length <= 10) {
      return address;
    }
    return '${address.substring(0, 6)}...'
        '${address.substring(address.length - 4)}';
  }
}
