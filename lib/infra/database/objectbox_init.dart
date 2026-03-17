import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/objectbox.g.dart' show getObjectBoxModel;
import 'package:flutter/foundation.dart';
import 'package:objectbox/objectbox.dart';
import 'package:path_provider/path_provider.dart';

Store? _sharedStore;
Future<Store>? _initializingStore;

@visibleForTesting
enum ObjectBoxOpenStrategy {
  create,
  attach,
}

@visibleForTesting
ObjectBoxOpenStrategy chooseObjectBoxOpenStrategy({
  required bool isOpenAtPath,
}) {
  return isOpenAtPath
      ? ObjectBoxOpenStrategy.attach
      : ObjectBoxOpenStrategy.create;
}

/// Initialize ObjectBox store for FF1 Bluetooth devices.
///
/// On Android process/lifecycle transitions, another isolate may already hold
/// the ObjectBox store open for the same path. In that case we attach instead
/// of creating a second store instance for the same directory.
Future<Store> initializeObjectBox() async {
  final existingStore = _sharedStore;
  if (existingStore != null && !existingStore.isClosed()) {
    return existingStore;
  }

  final inFlightInitialization = _initializingStore;
  if (inFlightInitialization != null) {
    return inFlightInitialization;
  }

  final initialization = _openObjectBoxStore();
  _initializingStore = initialization;
  try {
    final store = await initialization;
    _sharedStore = store;
    return store;
  } finally {
    _initializingStore = null;
  }
}

Future<Store> _openObjectBoxStore() async {
  final dir = await getApplicationDocumentsDirectory();
  final path = '${dir.path}/ff_objectbox';

  final strategy = chooseObjectBoxOpenStrategy(
    isOpenAtPath: Store.isOpen(path),
  );

  switch (strategy) {
    case ObjectBoxOpenStrategy.create:
      return Store(getObjectBoxModel(), directory: path);
    case ObjectBoxOpenStrategy.attach:
      return Store.attach(getObjectBoxModel(), path);
  }
}

/// Returns the initialized shared ObjectBox store.
///
/// Call [initializeObjectBox] before using this helper.
Store getInitializedObjectBoxStore() {
  final store = _sharedStore;
  if (store == null || store.isClosed()) {
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

@visibleForTesting
Future<void> resetObjectBoxStoreForTests() async {
  final store = _sharedStore;
  if (store != null && !store.isClosed()) {
    store.close();
  }
  _sharedStore = null;
  _initializingStore = null;
}
