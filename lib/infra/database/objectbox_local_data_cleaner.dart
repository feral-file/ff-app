import 'package:app/infra/database/objectbox_models.dart';
import 'package:objectbox/objectbox.dart';

/// Clears all local ObjectBox-backed app state.
class ObjectBoxLocalDataCleaner {
  /// Creates a cleaner for a specific ObjectBox [Store].
  ObjectBoxLocalDataCleaner(this._store);

  final Store _store;

  /// Removes per-address app state before SQLite replace, while preserving the
  /// tracked-address list itself.
  ///
  /// This deletes every [AppStateAddressEntity] row, which intentionally drops
  /// stored checkpoints, workflow status, and list-tokens cursors. After the
  /// new SQLite file is ready, tracked-address resume rebuilds fresh per-
  /// address state from [TrackedAddressEntity].
  Future<void> lightClear() async {
    _store.runInTransaction(TxMode.write, () {
      _store.box<RemoteAppConfigEntity>().removeAll();
      _store.box<AppStateAddressEntity>().removeAll();
    });
  }

  /// Removes all rows from every local ObjectBox entity used by the app.
  ///
  /// Includes tracked-address rows (user-added addresses) which was previously
  /// omitted and caused addresses to persist after "forget I exist".
  Future<void> clearAll() async {
    _store.runInTransaction(TxMode.write, () {
      _store.box<FF1BluetoothDeviceEntity>().removeAll();
      _store.box<RemoteAppConfigEntity>().removeAll();
      _store.box<AppStateEntity>().removeAll();
      _store.box<AppStateAddressEntity>().removeAll();
      _store.box<TrackedAddressEntity>().removeAll();
    });
  }
}
