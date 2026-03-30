// ignore_for_file: public_member_api_docs // Reason: small service API is self-descriptive and covered by provider usage.

import 'package:app/domain/constants/indexer_constants.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:logging/logging.dart';

/// Simple personal-token sync service with no worker orchestration.
class PersonalTokensSyncService {
  PersonalTokensSyncService({
    required IndexerService indexerService,
    required DatabaseService databaseService,
    required AppStateServiceBase appStateService,
    Logger? logger,
  }) : _indexerService = indexerService,
       _databaseService = databaseService,
       _appStateService = appStateService,
       _log = logger ?? Logger('PersonalTokensSyncService');

  final IndexerService _indexerService;
  final DatabaseService _databaseService;
  final AppStateServiceBase _appStateService;
  final Logger _log;

  Future<void> trackAddress(String address) {
    return _appStateService.trackPersonalAddress(address);
  }

  Future<void> untrackAddress(String address) {
    return _appStateService.clearAddressState(address);
  }

  Future<void> syncTrackedAddressesOnce() async {
    final tracked = await _appStateService.getTrackedPersonalAddresses();
    if (tracked.isEmpty) return;
    await syncAddresses(addresses: tracked);
  }

  /// Fetches tokens for address. Used for initial fetch after address is indexed.
  ///
  /// Paginates using indexer `nextOffset`. The next request offset is
  /// persisted in app state so restarts resume from the indexer cursor (which
  /// may differ from SQLite [Playlist.itemCount]). When a run finishes
  /// (`nextOffset == null`), persisted state is cleared so the next sync starts
  /// from [itemCount] again.
  ///
  /// This is independent of [AddressSyncCollectionService] which updates
  /// already-fetched tokens.
  Future<void> syncAddresses({required List<String> addresses}) async {
    if (addresses.isEmpty) return;

    final playlists = await _databaseService.getAddressPlaylists();
    final offsetByAddressKey = <String, int>{};
    for (final playlist in playlists) {
      final owner = playlist.ownerAddress;
      if (owner == null) continue;
      final key = _addressKey(owner);
      final persisted =
          await _appStateService.getPersonalTokensListFetchOffset(owner);
      offsetByAddressKey[key] = persisted ?? playlist.itemCount;
    }
    final playlistAddressByKey = <String, String>{
      for (final playlist in playlists)
        if (playlist.ownerAddress != null)
          _addressKey(playlist.ownerAddress!): playlist.ownerAddress!,
    };

    final active = <String, int>{
      for (final address in addresses.map((e) => e.trim()))
        if (offsetByAddressKey.containsKey(_addressKey(address)))
          _addressKey(address): offsetByAddressKey[_addressKey(address)]!,
    };

    if (active.isEmpty) return;

    while (active.isNotEmpty) {
      final currentAddressKeys = active.keys.toList(growable: false);
      for (final addressKey in currentAddressKeys) {
        final offset = active[addressKey];
        if (offset == null) continue;
        final playlistAddress = playlistAddressByKey[addressKey];
        if (playlistAddress == null) {
          active.remove(addressKey);
          continue;
        }
        final queryAddress = _addressForIndexer(playlistAddress);

        final page = await _indexerService.fetchTokensPageByAddresses(
          addresses: <String>[queryAddress],
          limit: indexerTokensPageSize,
          offset: offset,
        );

        if (page.tokens.isEmpty) {
          await _appStateService.setPersonalTokensListFetchOffset(
            address: queryAddress,
            nextFetchOffset: null,
          );
          active.remove(addressKey);
          continue;
        }

        await _databaseService.ingestTokensForAddress(
          address: queryAddress,
          tokens: page.tokens,
        );

        final next = page.nextOffset;
        await _appStateService.setPersonalTokensListFetchOffset(
          address: queryAddress,
          nextFetchOffset: next,
        );
        if (next == null) {
          active.remove(addressKey);
        } else {
          active[addressKey] = next;
        }
      }
    }

    await _databaseService.checkpoint();
    _log.info(
      'Completed personal token sync for ${addresses.length} address(es)',
    );
  }

  String _addressKey(String address) => address.toNormalizedAddress();

  String _addressForIndexer(String address) {
    final trimmed = address.trim();
    if (trimmed.startsWith('0x') || trimmed.startsWith('0X')) {
      return trimmed.startsWith('0X')
          ? '0x${trimmed.substring(2).toLowerCase()}'
          : trimmed.toLowerCase();
    }
    return trimmed;
  }
}
