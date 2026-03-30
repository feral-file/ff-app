import 'dart:async';
import 'dart:math';

import 'package:app/domain/constants/indexer_constants.dart';
import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_service_isolate.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
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
    required IndexerServiceIsolateOperations indexerServiceIsolate,
    required AppStateServiceBase appStateService,
  }) : _databaseService = databaseService,
       _domainAddressService = domainAddressService,
       _personalTokensSyncService = personalTokensSyncService,
       _indexerServiceIsolate = indexerServiceIsolate,
       _appStateService = appStateService {
    _indexerSyncService = indexerSyncService;
    _log = Logger('AddressService');
  }

  final DatabaseService _databaseService;
  final DomainAddressService _domainAddressService;
  final PersonalTokensSyncService _personalTokensSyncService;
  final IndexerServiceIsolateOperations _indexerServiceIsolate;
  final AppStateServiceBase _appStateService;
  late final IndexerSyncService _indexerSyncService;
  late final Logger _log;

  void Function(AddressIndexingJobResponse)? _onIndexingJobStatusCallback;

  /// Registers a callback for real-time indexer job status updates (pull
  /// status during indexAndSyncAddress).
  // ignore: use_setters_to_change_properties
  void setIndexingJobStatusCallback(
    void Function(AddressIndexingJobResponse)? callback,
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
  /// Paginates using the indexer offset cursor: `nextOffset == null` means
  /// there are no more pages (do not infer completion from page length).
  ///
  /// The first request uses [startOffset] when it is non-zero; otherwise the
  /// persisted indexer cursor from app state (if any), then `0`. Each page
  /// writes the next cursor so restarts during `syncingTokens` resume where
  /// the last page left off instead of replaying from the start.
  Future<int> syncTokens(String address, {int startOffset = 0}) async {
    const pageSize = indexerTokensPageSize;
    // Canonical form matches playlist owner + ingest (toNormalizedAddress) so
    // indexer queries and cursor keys stay aligned with SQLite rows.
    final queryAddress = _addressForIndexer(address);
    var persisted = await _appStateService.getPersonalTokensListFetchOffset(
      queryAddress,
    );
    // Stale cursor: ObjectBox offset from before SQLite was replaced while the
    // address playlist has no rows yet — do not skip the head of the list.
    if (persisted != null && startOffset == 0) {
      final playlists = await _databaseService.getAddressPlaylists();
      for (final p in playlists) {
        if (p.ownerAddress?.toNormalizedAddress() == queryAddress) {
          if (p.itemCount == 0) {
            await _appStateService.setPersonalTokensListFetchOffset(
              address: queryAddress,
              nextFetchOffset: null,
            );
            persisted = null;
          }
          break;
        }
      }
    }
    // Non-zero startOffset is for tests or explicit overrides; default path
    // prefers the stored cursor over replaying from 0 after process restart.
    var total = 0;
    int? nextOffset =
        startOffset != 0 ? startOffset : (persisted ?? 0);
    while (true) {
      final page = await _indexerServiceIsolate.fetchTokensPageByAddresses(
        addresses: [queryAddress],
        limit: pageSize,
        offset: nextOffset,
      );
      if (page.tokens.isNotEmpty) {
        await _databaseService.ingestTokensForAddress(
          address: queryAddress,
          tokens: page.tokens,
        );
        total += page.tokens.length;
      }
      final cursor = page.nextOffset;
      await _appStateService.setPersonalTokensListFetchOffset(
        address: queryAddress,
        nextFetchOffset: cursor,
      );
      if (cursor == null) break;
      nextOffset = cursor;
    }
    return total;
  }

  /// Runs indexing flow: index → poll → fetch+ingest.
  ///
  /// Single flow. Each step has a flag — set to false when that step was
  /// already done (e.g. on app restart). Pass workflow id when trigger index is
  /// false and poll is true.
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
    _log.info(
      'Indexing and syncing address: $address, runFastPathFetch: '
          '$runFastPathFetch, runTriggerIndex: $runTriggerIndex, '
          'runPoll: $runPoll, runFinalFetch: $runFinalFetch, '
          'workflowId: $workflowId',
    );
    final queryAddress = _addressForIndexer(address);
    var effectiveWorkflowId = workflowId;

    // Persist "trigger submitted, workflow id not known yet" so Me / playlist
    // headers show Syncing before the indexer trigger returns (same contract as
    // add-address recovery in app.dart). Avoid idle, which means no active
    // indexing process.
    if (runTriggerIndex) {
      await _appStateService.setAddressIndexingStatus(
        address: queryAddress,
        status: AddressIndexingProcessStatus.indexingTriggeredPending(),
      );
    }

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
        // log the workflow id
        _log.info('Indexing triggered for $queryAddress with workflowId: $id');
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
      _log.warning(
        'workflowId required when runTriggerIndex is false and runPoll is true',
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

      _log.info(
        'Polling for address indexing status for $queryAddress with '
        'workflowId: $wfId',
      );

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

  /// Resumes indexing for addresses with non-completed status.
  ///
  /// Called by the ensure-playlists-and-resume flow after playlists are
  /// ensured. Fetches status per address from app state; each address is
  /// processed according to its status (idle→trigger index,
  /// indexingTriggered→poll, etc.).
  Future<void> resumeIndexingForAddresses(
    List<String> toResume, {
    Random? random,
  }) async {
    final rnd = random ?? Random();
    final statuses = await _appStateService.getAllAddressIndexingStatuses();
    for (final address in toResume) {
      await Future<void>.delayed(
        Duration(milliseconds: 100 + rnd.nextInt(401)),
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
  Future<void> addAddressOrDomain({
    required String value,
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

    await addAddress(walletAddress: walletAddress);
  }

  /// Add a wallet address: validate, dup-check via getTrackedPersonalAddresses,
  /// then write ObjectBox (addTrackedAddress, setAddressIndexingStatus).
  ///
  /// If duplicate, throws Exception('Address already added').
  /// Playlist creation and indexing are triggered by the ensure-playlists-and-
  /// resume provider.
  Future<void> addAddress({
    required WalletAddress walletAddress,
  }) async {
    try {
      final chain = walletAddress.chain;
      final normalizedAddress = walletAddress.address.toNormalizedAddress();
      _log.info('Adding address: $normalizedAddress on chain $chain');

      final alreadyAdded = await isAddressAlreadyAdded(
        address: walletAddress.address,
        chain: Chain.fromAddress(walletAddress.address),
      );
      if (alreadyAdded) {
        throw Exception('Address already added');
      }

      await _appStateService.addTrackedAddress(
        normalizedAddress,
        alias: walletAddress.name,
      );
      await _appStateService.setAddressIndexingStatus(
        address: normalizedAddress,
        status: AddressIndexingProcessStatus.idle(),
      );

      _log.info('Added tracked address: $normalizedAddress');
    } catch (e, stack) {
      _log.severe('Failed to add address $walletAddress', e, stack);
      rethrow;
    }
  }

  /// Returns true when the address has already been added.
  ///
  /// Uses getTrackedPersonalAddresses as single source of truth.
  Future<bool> isAddressAlreadyAdded({
    required String address,
    required Chain chain,
  }) async {
    final normalizedInput = address.normalizeForComparison(chain: chain);
    final tracked = await _appStateService.getTrackedPersonalAddresses();
    return tracked.any(
      (value) => value.normalizeForComparison(chain: chain) == normalizedInput,
    );
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

      final playlist = await _databaseService.getPlaylistById(
        resolvedPlaylistId,
      );
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
