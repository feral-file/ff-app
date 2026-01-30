import 'package:app/objectbox.g.dart' show getObjectBoxModel;
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';

import 'objectbox_models.dart';

/// Initialize ObjectBox store for FF1 Bluetooth devices.
///
/// This function:
/// 1. Gets the application documents directory
/// 2. Creates the ObjectBox store with FF1BluetoothDeviceEntity
/// 3. Returns the initialized store
///
/// Should be called once during app initialization in main.dart.
Future<Store> initializeObjectBox() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/ff_objectbox';

    // Create and return the ObjectBox store
    // ObjectBox will automatically create the directory
    final store = Store(getObjectBoxModel(), directory: path);
    return store;
  } catch (e) {
    throw Exception('Failed to initialize ObjectBox: $e');
  }
}

/// Helper function to get the box for FF1BluetoothDeviceEntity
Box<FF1BluetoothDeviceEntity> getBluetoothDeviceBox(Store store) {
  return store.box<FF1BluetoothDeviceEntity>();
}
