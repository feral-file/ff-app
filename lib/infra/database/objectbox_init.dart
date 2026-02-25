import 'package:app/objectbox.g.dart' show getObjectBoxModel;
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';

import 'package:app/infra/database/objectbox_models.dart';

Store? _sharedStore;

/// Initialize ObjectBox store for FF1 Bluetooth devices.
///
/// This function:
/// 1. Gets the application documents directory
/// 2. Creates the ObjectBox store with FF1BluetoothDeviceEntity
/// 3. Returns the initialized store
///
/// Should be called once during app initialization in main.dart.
Future<Store> initializeObjectBox() async {
  if (_sharedStore != null) {
    return _sharedStore!;
  }
  try {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/ff_objectbox';

    // Create and return the ObjectBox store
    // ObjectBox will automatically create the directory
    _sharedStore = Store(getObjectBoxModel(), directory: path);
    return _sharedStore!;
  } catch (e) {
    throw Exception('Failed to initialize ObjectBox: $e');
  }
}

/// Returns the initialized shared ObjectBox store.
///
/// Call [initializeObjectBox] before using this helper.
Store getInitializedObjectBoxStore() {
  final store = _sharedStore;
  if (store == null) {
    throw StateError(
      'ObjectBox store is not initialized. Call initializeObjectBox() first.',
    );
  }
  return store;
}

/// Helper function to get the box for FF1BluetoothDeviceEntity
Box<FF1BluetoothDeviceEntity> getBluetoothDeviceBox(Store store) {
  return store.box<FF1BluetoothDeviceEntity>();
}
