import 'package:app/infra/database/objectbox_local_data_cleaner.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';

class _MockStore implements Store {
  late Box<RemoteAppConfigEntity> remoteAppConfigBox;
  late Box<AppStateAddressEntity> appStateAddressBox;
  late Box<TrackedAddressEntity> trackedAddressBox;

  @override
  R runInTransaction<R>(TxMode mode, R Function() callback) => callback();

  @override
  Box<T> box<T>() {
    if (T == RemoteAppConfigEntity) {
      return remoteAppConfigBox as Box<T>;
    }
    if (T == AppStateAddressEntity) {
      return appStateAddressBox as Box<T>;
    }
    if (T == TrackedAddressEntity) {
      return trackedAddressBox as Box<T>;
    }
    throw UnsupportedError('Unexpected box<$T>() in test');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingRemoteAppConfigBox implements Box<RemoteAppConfigEntity> {
  int removeAllCalls = 0;

  @override
  int removeAll() {
    removeAllCalls++;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingAppStateAddressBox implements Box<AppStateAddressEntity> {
  int removeAllCalls = 0;

  @override
  int removeAll() {
    removeAllCalls++;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingTrackedAddressBox implements Box<TrackedAddressEntity> {
  int removeAllCalls = 0;

  @override
  int removeAll() {
    removeAllCalls++;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'lightClear removes per-address app state but keeps tracked addresses',
    () async {
      final store = _MockStore();
      final remoteBox = _RecordingRemoteAppConfigBox();
      final appStateAddressBox = _RecordingAppStateAddressBox();
      final trackedAddressBox = _RecordingTrackedAddressBox();
      store
        ..remoteAppConfigBox = remoteBox
        ..appStateAddressBox = appStateAddressBox
        ..trackedAddressBox = trackedAddressBox;

      await ObjectBoxLocalDataCleaner(store).lightClear();

      expect(remoteBox.removeAllCalls, 1);
      expect(appStateAddressBox.removeAllCalls, 1);
      expect(trackedAddressBox.removeAllCalls, 0);
    },
  );
}
