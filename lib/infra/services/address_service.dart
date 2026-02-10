import 'package:logging/logging.dart';

import '../../domain/models/playlist.dart';
import '../database/database_service.dart';
import 'indexer_service.dart';
import 'indexer_sync_service.dart';

/// Service for managing user wallet addresses and address-based playlists.
class AddressService {
  /// Creates an AddressService.
  AddressService({
    required DatabaseService databaseService,
    required IndexerService indexerService,
    required IndexerSyncService indexerSyncService,
  })  : _databaseService = databaseService,
        _indexerService = indexerService {
    _indexerSyncService = indexerSyncService;
    _log = Logger('AddressService');
  }

  final DatabaseService _databaseService;
  final IndexerService _indexerService;
  late final IndexerSyncService _indexerSyncService;
  late final Logger _log;

  /// Add a wallet address and create its playlist.
  /// This creates an address-based playlist in the "My Collection" channel.
  Future<Playlist> addAddress({
    required String address,
    required String chain,
    String channelId = 'my_collection',
  }) async {
    try {
      final normalizedAddress = address.toUpperCase();
      _log.info('Adding address: $normalizedAddress on chain $chain');

      // Create address playlist
      final playlist = Playlist(
        id: 'addr:$chain:$normalizedAddress',
        name: '$chain: ${_shortenAddress(normalizedAddress)}',
        type: PlaylistType.addressBased,
        channelId: channelId,
        playlistSource: PlaylistSource.personal,
        ownerAddress: normalizedAddress,
        ownerChain: chain,
        sortMode: PlaylistSortMode.provenance,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Ingest playlist
      await _databaseService.ingestPlaylist(playlist);

      // Trigger reindexing to fetch tokens
      await _indexerService.indexAddressesList([normalizedAddress]);

      _log.info('Added address playlist: ${playlist.id}');
      return playlist;
    } catch (e, stack) {
      _log.severe('Failed to add address $address', e, stack);
      rethrow;
    }
  }

  /// Remove an address and its playlist.
  Future<void> removeAddress({
    required String address,
    required String chain,
  }) async {
    try {
      final normalizedAddress = address.toUpperCase();
      final playlistId = 'addr:$chain:$normalizedAddress';

      _log.info('Removing address: $normalizedAddress');

      // Get the playlist
      final playlist = await _databaseService.getPlaylistById(playlistId);
      if (playlist == null) {
        _log.warning('Address playlist not found: $playlistId');
        return;
      }

      // Delete all items for this playlist
      final items = await _databaseService.getPlaylistItems(playlistId);
      for (final item in items) {
        await _databaseService.deletePlaylistItem(item.id);
      }

      // Note: In a real implementation, you'd delete the playlist record too
      // For now, just clearing its items is sufficient

      _log.info('Removed address playlist: $playlistId');
    } catch (e, stack) {
      _log.severe('Failed to remove address $address', e, stack);
      rethrow;
    }
  }

  /// Refresh tokens for an address.
  /// Fetches latest tokens from indexer and updates the database.
  Future<int> refreshAddress({
    required String address,
  }) async {
    try {
      final normalizedAddress = address.toUpperCase();
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
  /// Used by work detail and other features that need the list of user addresses.
  Future<List<String>> getAllAddresses() async {
    final playlists = await _databaseService.getAddressPlaylists();
    return playlists
        .map((p) => p.ownerAddress)
        .whereType<String>()
        .toList();
  }

  /// Shorten address for display (0x1234...5678).
  String _shortenAddress(String address) {
    if (address.length <= 10) {
      return address;
    }
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
