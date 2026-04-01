// ignore_for_file: public_member_api_docs // Reason: small service API is self-descriptive and covered by provider usage.

import 'package:app/domain/constants/indexer_constants.dart';
import 'package:app/domain/utils/address_deduplication.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/address_tokens_sync_lock.dart';
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

  /// Fetches tokens for address (initial fetch after address is indexed).
  ///
  /// Paginates using indexer `nextOffset`. The next request offset is
  /// persisted in app state so restarts resume from the indexer cursor (which
  /// may differ from SQLite playlist row count). When a run finishes
  /// (`nextOffset == null`), persisted state is cleared so the next sync starts
  /// from row count again.
  ///
  /// This is independent of sync-collection updates for already-fetched tokens.
  Future<void> syncAddresses({required List<String> addresses}) async {
    if (addresses.isEmpty) return;

    final playlists = await _databaseService.getAddressPlaylists();
    final playlistAddressByKey = <String, String>{
      for (final playlist in playlists)
        if (playlist.ownerAddress != null)
          _addressKey(playlist.ownerAddress!): playlist.ownerAddress!,
    };
    final requestedKeys = <String>{
      for (final address in addresses.map((e) => e.trim()))
        if (playlistAddressByKey.containsKey(_addressKey(address)))
          _addressKey(address),
    };

    if (requestedKeys.isEmpty) return;

    for (final addressKey in requestedKeys) {
      final playlistAddress = playlistAddressByKey[addressKey];
      if (playlistAddress == null) continue;
      final queryAddress = playlistAddress.toNormalizedAddress();
      await addressTokensSyncLock(queryAddress).synchronized(() async {
        await _syncAddress(
          queryAddress: queryAddress,
          initialOffset: await _initialOffsetForAddress(
            queryAddress: queryAddress,
            playlistItemCount: await _playlistItemCountForAddress(queryAddress),
          ),
        );
      });
    }

    await _databaseService.checkpoint();
    _log.info(
      'Completed personal token sync for ${addresses.length} address(es)',
    );
  }

  String _addressKey(String address) => address.toNormalizedAddress();

  Future<int> _initialOffsetForAddress({
    required String queryAddress,
    required int playlistItemCount,
  }) async {
    final persisted = await _appStateService.getPersonalTokensListFetchOffset(
      queryAddress,
    );
    return persisted ?? playlistItemCount;
  }

  Future<int> _playlistItemCountForAddress(String queryAddress) async {
    final playlists = await _databaseService.getAddressPlaylists();
    for (final playlist in playlists) {
      if (playlist.ownerAddress?.toNormalizedAddress() == queryAddress) {
        return playlist.itemCount;
      }
    }
    return 0;
  }

  Future<void> _syncAddress({
    required String queryAddress,
    required int initialOffset,
  }) async {
    var nextOffset = initialOffset;
    while (true) {
      final page = await _indexerService.fetchTokensPageByAddresses(
        addresses: <String>[queryAddress],
        limit: indexerTokensPageSize,
        offset: nextOffset,
      );

      if (page.tokens.isNotEmpty) {
        await _databaseService.ingestTokensForAddress(
          address: queryAddress,
          tokens: page.tokens,
        );
      }

      final next = page.nextOffset;
      await _appStateService.setPersonalTokensListFetchOffset(
        address: queryAddress,
        nextFetchOffset: next,
      );
      if (next == null) return;
      nextOffset = next;
    }
  }
}
