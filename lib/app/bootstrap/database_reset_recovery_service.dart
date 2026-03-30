import 'package:app/infra/config/app_state_service.dart';

/// Recovers ObjectBox app state after a database reset when the DP-1 SQLite
/// library still contains address playlists.
///
/// The reset marker indicates that ObjectBox was cleared (tracked addresses,
/// checkpoints, and per-address indexing state), but SQLite is the source of
/// truth for which personal address playlists exist.
///
/// Invariants:
/// - The recovered address must be marked as tracked before persisting any
///   per-address app state (because AppStateService ignores writes for
///   untracked addresses to avoid recreating rows after removal).
/// - The recovered indexing state is set to `indexingTriggeredPending` so the
///   ensure-playlists-and-resume flow can continue without incorrectly
///   restarting from `idle`.
class DatabaseResetRecoveryService {
  DatabaseResetRecoveryService({
    required AppStateServiceBase appStateService,
  }) : _appStateService = appStateService;

  final AppStateServiceBase _appStateService;

  Future<void> recover({
    required List<String> normalizedAddresses,
    required String Function(String address) aliasForAddress,
  }) async {
    for (final address in normalizedAddresses) {
      await _appStateService.clearAddressCheckpoint(address);
      await _appStateService.addTrackedAddress(
        address,
        alias: aliasForAddress(address),
      );
      await _appStateService.setAddressIndexingStatus(
        address: address,
        status: AddressIndexingProcessStatus.indexingTriggeredPending(),
      );
    }
  }
}

String shortAddressAlias(String address) {
  if (address.length <= 10) {
    return address;
  }
  return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}

