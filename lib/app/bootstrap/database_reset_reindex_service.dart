import 'package:app/infra/config/app_state_service.dart';

/// Resets tracked-address indexing state after the DP-1 SQLite file was
/// recreated outside the normal seed-replace flow.
///
/// The source of truth for user-added addresses remains the tracked-address
/// ObjectBox list. When Drift recreates `dp1_library.sqlite` after an
/// open/schema failure, any persisted checkpoint, workflow status, or
/// list-tokens cursor in per-address app state becomes stale because the
/// address playlists/items in SQLite were lost. This service clears that stale
/// progress so the normal tracked-address resume flow can recreate playlists
/// and restart indexing deterministically from the tracked list.
class DatabaseResetReindexService {
  /// Creates a reset helper bound to the shared app-state service.
  DatabaseResetReindexService({
    required AppStateServiceBase appStateService,
  }) : _appStateService = appStateService;

  final AppStateServiceBase _appStateService;

  /// Consumes the reset marker and rewrites tracked-address app state when the
  /// local SQLite library was recreated.
  ///
  /// Returns true when the marker was present (even if there were no tracked
  /// addresses left to rewrite).
  Future<bool> resetTrackedAddressesIfNeeded({
    required Future<bool> Function() consumeResetMarker,
  }) async {
    final requiresReindex = await consumeResetMarker();
    if (!requiresReindex) {
      return false;
    }

    final trackedAddresses = await _appStateService
        .getTrackedPersonalAddresses();
    for (final address in trackedAddresses) {
      await _appStateService.clearAddressCheckpoint(address);
      await _appStateService.setPersonalTokensListFetchOffset(
        address: address,
        nextFetchOffset: null,
      );
      await _appStateService.setAddressIndexingStatus(
        address: address,
        status: AddressIndexingProcessStatus.idle(),
      );
    }
    return true;
  }
}
