import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/domain_address_service.dart';
import 'package:app/infra/services/address_indexing_process_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:logging/logging.dart';

/// Service for managing user wallet addresses and address-based playlists.
class AddressService {
  /// Creates an AddressService.
  AddressService({
    required DatabaseService databaseService,
    required IndexerSyncService indexerSyncService,
    required DomainAddressService domainAddressService,
    required AddressIndexingProcessService addressIndexingProcessService,
  }) : _databaseService = databaseService,
       _domainAddressService = domainAddressService,
       _addressIndexingProcessService = addressIndexingProcessService {
    _indexerSyncService = indexerSyncService;
    _log = Logger('AddressService');
  }

  final DatabaseService _databaseService;
  final DomainAddressService _domainAddressService;
  final AddressIndexingProcessService _addressIndexingProcessService;
  late final IndexerSyncService _indexerSyncService;
  late final Logger _log;

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
        await _addressIndexingProcessService.start(normalizedAddress);
        return existing;
      }

      final playlist = PlaylistExt.fromWalletAddress(
        walletAddress,
        channelId: channelId,
      );

      await _databaseService.ingestPlaylist(playlist);
      await _addressIndexingProcessService.start(normalizedAddress);

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
      final playlistId = PlaylistExt.addressPlaylistId(normalizedAddress);

      _log.info('Removing address: $normalizedAddress');
      await _addressIndexingProcessService.stop(normalizedAddress);

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

  /// Pause indexing/sync process for an address.
  Future<void> pauseAddressProcessing(String address) async {
    final normalizedAddress = _normalizeAddressForChain(address);
    await _addressIndexingProcessService.pause(normalizedAddress);
  }

  /// Resume indexing/sync process for an address.
  Future<void> resumeAddressProcessing(String address) async {
    final normalizedAddress = _normalizeAddressForChain(address);
    await _addressIndexingProcessService.resume(normalizedAddress);
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
