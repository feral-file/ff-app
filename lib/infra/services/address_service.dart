import 'package:app/domain/models/models.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/indexer_enrichment_scheduler_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:logging/logging.dart';

/// Service for managing user wallet addresses and address-based playlists.
class AddressService {
  /// Creates an AddressService.
  AddressService({
    required DatabaseService databaseService,
    required IndexerService indexerService,
    required IndexerSyncService indexerSyncService,
    required DomainAddressService domainAddressService,
    required IndexerEnrichmentSchedulerService enrichmentScheduler,
  }) : _databaseService = databaseService,
       _indexerService = indexerService,
       _domainAddressService = domainAddressService,
       _enrichmentScheduler = enrichmentScheduler {
    _indexerSyncService = indexerSyncService;
    _log = Logger('AddressService');
  }

  final DatabaseService _databaseService;
  final IndexerService _indexerService;
  final DomainAddressService _domainAddressService;
  final IndexerEnrichmentSchedulerService _enrichmentScheduler;
  late final IndexerSyncService _indexerSyncService;
  late final Logger _log;
  static const Duration _indexingPollDelay = Duration(seconds: 5);
  static const Duration _indexingTimeout = Duration(minutes: 15);

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
  /// This creates an address-based playlist in the "My Collection" channel.
  Future<Playlist> addAddress({
    required WalletAddress walletAddress,
    String channelId = 'my_collection',
  }) async {
    try {
      final chain = walletAddress.chain;
      final normalizedAddress = _normalizeAddressForChain(
        walletAddress.address,
        chain: chain,
      );
      _log.info('Adding address: $normalizedAddress on chain $chain');

      final existing = await _getAddressPlaylistByOwner(normalizedAddress);
      if (existing != null) {
        _log.info('Address playlist already exists: ${existing.id}');
        await _runAddressIndexingAndEnrichment(normalizedAddress);
        return existing;
      }

      final playlist = Playlist(
        id: 'addr:$chain:$normalizedAddress',
        name: walletAddress.name,
        type: PlaylistType.addressBased,
        channelId: channelId,
        ownerAddress: normalizedAddress,
        ownerChain: chain,
        sortMode: PlaylistSortMode.provenance,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _databaseService.ingestPlaylist(playlist);
      await _runAddressIndexingAndEnrichment(normalizedAddress);

      _log.info('Added address playlist: ${playlist.id}');
      return playlist;
    } catch (e, stack) {
      _log.severe('Failed to add address $walletAddress', e, stack);
      rethrow;
    }
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
      final playlistId = 'addr:$chain:$normalizedAddress';

      _log.info('Removing address: $normalizedAddress');

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

  /// Ensure the default startup addresses exist.
  ///
  /// This is intentionally idempotent and safe to call on every app startup.
  Future<void> ensureDefaultAddressOnStartup() async {
    const defaultDomains = ['einstein-rosen.eth', 'einstein-rosen.tez'];

    for (final defaultDomain in defaultDomains) {
      try {
        final resolved = await _domainAddressService.verifyAddressOrDomain(
          defaultDomain,
        );
        if (resolved == null) {
          _log.warning(
            'Could not resolve default startup domain: $defaultDomain',
          );
          continue;
        }

        final chain = _chainStringFromType(resolved.type);
        final normalizedAddress = _normalizeAddressForChain(
          resolved.address,
          chain: chain,
        );

        final existing = await _getAddressPlaylistByOwner(normalizedAddress);
        if (existing != null) {
          await _runAddressIndexingAndEnrichment(normalizedAddress);
          continue;
        }

        await addAddress(
          walletAddress: WalletAddress(
            address: normalizedAddress,
            createdAt: DateTime.now(),
            name: resolved.domain ?? _shortenAddress(normalizedAddress),
          ),
        );
      } on Object catch (e, stack) {
        _log.warning(
          'Failed to auto-add default startup address ($defaultDomain)',
          e,
          stack,
        );
      }
    }
  }

  Future<void> _runAddressIndexingAndEnrichment(
    String normalizedAddress,
  ) async {
    try {
      final results = await _indexerService.indexAddressesList([
        normalizedAddress,
      ]);
      var workflowId = '';
      for (final result in results) {
        if (!_addressesEqual(result.address, normalizedAddress)) {
          continue;
        }
        if (result.workflowId.isEmpty) {
          continue;
        }
        workflowId = result.workflowId;
        break;
      }

      if (workflowId.isNotEmpty) {
        await _waitForAddressIndexingWorkflow(
          workflowId: workflowId,
          address: normalizedAddress,
        );
      }
    } on Object catch (e, stack) {
      _log.warning(
        'Trigger/wait indexing failed for $normalizedAddress; '
        'continuing with direct token fetch',
        e,
        stack,
      );
    }

    _enrichmentScheduler.enqueuePersonalAddress(normalizedAddress);
    _enrichmentScheduler.notifyFeedWorkAvailable();
  }

  Future<void> _waitForAddressIndexingWorkflow({
    required String workflowId,
    required String address,
  }) async {
    final startedAt = DateTime.now();

    while (true) {
      AddressIndexingJobResponse? status;
      try {
        status = await _indexerService.getAddressIndexingJobStatus(
          workflowId: workflowId,
        );
      } on Object catch (e, stack) {
        _log.warning(
          'Failed to read indexing status for $address workflow=$workflowId; '
          'will retry',
          e,
          stack,
        );
      }

      if (status != null && status.status.isDone) {
        if (!status.status.isSuccess) {
          _log.warning(
            'Address indexing finished with non-success status '
            'for $address: ${status.status.name}',
          );
        }
        return;
      }

      if (DateTime.now().difference(startedAt) > _indexingTimeout) {
        _log.warning(
          'Timed out waiting for indexing workflow $workflowId for $address',
        );
        return;
      }

      await Future<void>.delayed(_indexingPollDelay);
    }
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

  String _chainStringFromType(Chain chain) {
    return switch (chain) {
      Chain.ethereum => 'ETH',
      Chain.tezos => 'TEZ',
      Chain.unknown => 'UNKNOWN',
    };
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
