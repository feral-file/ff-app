import 'package:app/infra/database/objectbox_models.dart';
import 'package:objectbox/objectbox.dart';

/// Clears all local ObjectBox-backed app state.
class ObjectBoxLocalDataCleaner {
  /// Creates a cleaner for a specific ObjectBox [Store].
  ObjectBoxLocalDataCleaner(this._store);

  final Store _store;

  /// Removes all rows from every local ObjectBox entity used by the app.
  Future<void> clearAll() async {
    _store.runInTransaction(TxMode.write, () {
      _store.box<FF1BluetoothDeviceEntity>().removeAll();
      _store.box<RemoteAppConfigEntity>().removeAll();
      _store.box<AppStateEntity>().removeAll();
      _store.box<AppStateAddressEntity>().removeAll();
      _store.box<WorkerStateEntity>().removeAll();
    });
  }
}
