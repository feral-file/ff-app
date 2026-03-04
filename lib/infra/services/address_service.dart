import 'dart:async';

import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/domain/utils/address_deduplication.dart';
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
  }) : _databaseService = databaseService,
       _domainAddressService = domainAddressService,
       _personalTokensSyncService = personalTokensSyncService,
       _pendingAddressesStore = pendingAddressesStore,
       _indexerServiceIsolate = indexerServiceIsolate {
    _indexerSyncService = indexerSyncService;
    _log = Logger('AddressService');
  }

  final DatabaseService _databaseService;
  final DomainAddressService _domainAddressService;
  final PersonalTokensSyncService _personalTokensSyncService;
  final PendingAddressesStore _pendingAddressesStore;
  final IndexerServiceIsolateOperations _indexerServiceIsolate;
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

  /// Fetches tokens page for address and ingests into DB. Returns count ingested.
  Future<int> syncTokens(String address, {int offset = 0}) async {
    const pageSize = 50;
    final page = await _indexerServiceIsolate.fetchTokensPageByAddresses(
      addresses: [address],
      limit: pageSize,
      offset: offset,
    );
    if (page.tokens.isEmpty) return 0;
    await _databaseService.ingestTokensForAddress(
      address: address,
      tokens: page.tokens,
    );
    return page.tokens.length;
  }

  /// Runs full indexing flow: index → poll → fetch+ingest each poll until done.
  ///
  /// Fast-path: if tokens exist at offset 0, paginate and ingest.
  /// Slow-path: trigger index, poll status, fetch+ingest on each poll (incremental UX).
  Future<void> indexAndSyncAddress(String address) async {
    final queryAddress = _addressForIndexer(address);

    // Fast-path: try fetch first
    var offset = 0;
    var totalIngested = 0;
    while (true) {
      final count = await syncTokens(queryAddress, offset: offset);
      if (count == 0) break;
      totalIngested += count;
      offset += count;
      if (count < 50) break;
    }
    if (totalIngested > 0) {
      _log.info('IndexAndSync fast-path completed for $queryAddress');
      return;
    }

    // Slow-path: trigger indexing
    final workflowId = await index(queryAddress);
    if (workflowId == null || workflowId.isEmpty) {
      throw Exception('No workflow ID returned for address: $queryAddress');
    }

    const pollInterval = Duration(seconds: 5);
    const maxAttempts = 60;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final status = await pullStatus(workflowId);
      _onIndexingJobStatusCallback?.call(status);

      if (status.status.isDone) {
        if (!status.status.isSuccess) {
          throw Exception(
            'Indexing failed with status: ${status.status.name}',
          );
        }
        break;
      }

      // Incremental UX: fetch and ingest on each poll
      offset = 0;
      while (true) {
        final count = await syncTokens(queryAddress, offset: offset);
        if (count == 0) break;
        offset += count;
        if (count < 50) break;
      }

      await Future<void>.delayed(pollInterval);
    }

    // Final fetch after completion
    offset = 0;
    while (true) {
      final count = await syncTokens(queryAddress, offset: offset);
      if (count == 0) break;
      offset += count;
      if (count < 50) break;
    }

    _log.info('IndexAndSync completed for $queryAddress');
  }

  String _addressForIndexer(String address) {
    final trimmed = address.trim();
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return trimmed.startsWith('0X')
          ? '0x${trimmed.substring(2).toLowerCase()}'
          : trimmed.toLowerCase();
    }
    return trimmed;
  }

  /// Add an address from either a raw address or ENS/TNS domain.
  Future<Playlist> addAddressOrDomain({
    required String value,
    String channelId = 'my_collection',
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
  Future<Playlist> addAddress({
    required WalletAddress walletAddress,
    String channelId = 'my_collection',
    bool syncNow = true,
  }) async {
    try {
      final chain = walletAddress.chain;
      final normalizedAddress = _normalizeAddressForChain(
        walletAddress.address,
        chain: chain,
      );
      _log.info('Adding address: $normalizedAddress on chain $chain');

      if (!SeedDatabaseGate.isCompleted) {
        // DB not ready yet: persist the address in the pending store so it
        // survives navigation and is migrated to SQLite after the seed lands.
        await _pendingAddressesStore.addAddress(normalizedAddress);
        if (syncNow) {
          // track address and sync immediately
          _scheduleAddressIndexing(normalizedAddress);
        } else {
          // track address and sync later
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
  Future<void> removeAddress({
    required WalletAddress walletAddress,
  }) async {
    try {
      final chain = walletAddress.chain;
      final normalizedAddress = _normalizeAddressForChain(
        walletAddress.address,
        chain: chain,
      );
      final playlistId = PlaylistExt.addressPlaylistId(normalizedAddress);

      _log.info('Removing address: $normalizedAddress');
      await _personalTokensSyncService.untrackAddress(normalizedAddress);

      final playlist = await _databaseService.getPlaylistById(playlistId);
      if (playlist == null) {
        _log.warning('Address playlist not found: $playlistId');
        return;
      }

      final items = await _databaseService.getPlaylistItems(playlistId);
      for (final item in items) {
        await _databaseService.deletePlaylistItem(item.id);
      }

      await _databaseService.deletePlaylist(playlistId);

      _log.info('Removed address playlist: $playlistId');
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
      final normalizedAddress = _normalizeAddressForChain(address);
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

  String _normalizeAddressForChain(
    String address, {
    String? chain,
  }) {
    final trimmed = address.trim();
    final chainName = chain?.toLowerCase();
    if (chainName == 'ethereum' ||
        chainName == 'eth' ||
        _isEthereumAddress(trimmed)) {
      return _normalizeEthereumAddress(trimmed);
    }
    return trimmed;
  }

  bool _isEthereumAddress(String address) {
    return address.startsWith('0x') || address.startsWith('0X');
  }

  String _normalizeEthereumAddress(String address) {
    if (address.startsWith('0X')) {
      return '0x${address.substring(2)}';
    }
    return address;
  }

  bool _addressesEqual(String left, String right) {
    if (_isEthereumAddress(left) || _isEthereumAddress(right)) {
      return left.toLowerCase() == right.toLowerCase();
    }
    return left == right;
  }

  /// Shorten address for display (0x1234...5678).
  String _shortenAddress(String address) {
    if (address.length <= 10) {
      return address;
    }
    return '${address.substring(0, 6)}...'
        '${address.substring(address.length - 4)}';
  }
}
