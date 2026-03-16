import 'package:app/infra/database/async_once.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/objectbox.g.dart' show getObjectBoxModel;
import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';

final AsyncOnce<Store> _storeLoader = AsyncOnce<Store>();

/// Initialize ObjectBox store for FF1 Bluetooth devices.
///
/// This function:
/// 1. Gets the application documents directory
/// 2. Creates the ObjectBox store with FF1BluetoothDeviceEntity
/// 3. Returns the initialized store
///
/// Should be called once during app initialization in main.dart.
Future<Store> initializeObjectBox() {
  return _storeLoader.run(_openObjectBoxStore);
}

Future<Store> _openObjectBoxStore() async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/ff_objectbox';
  return Store(getObjectBoxModel(), directory: path);
}

/// Returns the initialized shared ObjectBox store.
///
/// Call [initializeObjectBox] before using this helper.
Store getInitializedObjectBoxStore() {
  if (!_storeLoader.hasValue) {
    throw StateError(
      'ObjectBox store is not initialized. Call initializeObjectBox() first.',
    );
  }

  return _storeLoader.value;
}

/// Helper function to get the box for FF1BluetoothDeviceEntity
Box<FF1BluetoothDeviceEntity> getBluetoothDeviceBox(Store store) {
  return store.box<FF1BluetoothDeviceEntity>();
}

@visibleForTesting
Future<void> resetObjectBoxStoreForTests() async {
  if (_storeLoader.hasValue) {
    final store = _storeLoader.value;
    if (!store.isClosed()) {
      store.close();
    }
  }

  _storeLoader.reset();
}
