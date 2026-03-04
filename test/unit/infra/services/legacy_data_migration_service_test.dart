import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/services/legacy_data_migration_service.dart';
import 'package:app/infra/services/legacy_storage_locator.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLegacyStorageLocator extends LegacyStorageLocator {
  _FakeLegacyStorageLocator({
    required this.hasLegacyDb,
  });

  final bool hasLegacyDb;

  @override
  Future<bool> hasLegacySqliteDatabase() async {
    return hasLegacyDb;
  }
}

void main() {
  group('LegacyDataMigrationService', () {
    test(
      'shouldRunMigration is true when legacy DB exists and not migrated',
      () async {
        final service = LegacyDataMigrationService(
          storageLocator: _FakeLegacyStorageLocator(hasLegacyDb: true),
          isMigratedOverride: () async => false,
        );

        final shouldRun = await service.shouldRunMigration();
        expect(shouldRun, isTrue);
      },
    );

    test(
      'shouldRunMigration is false when legacy DB is missing',
      () async {
        final service = LegacyDataMigrationService(
          storageLocator: _FakeLegacyStorageLocator(hasLegacyDb: false),
          isMigratedOverride: () async => false,
        );

        final shouldRun = await service.shouldRunMigration();
        expect(shouldRun, isFalse);
      },
    );

    test('skips migration when already migrated', () async {
      var setMigratedCalled = false;
      final migratedAddresses = <String>[];
      final migratedDevices = <FF1Device>[];

      final service = LegacyDataMigrationService(
        storageLocator: _FakeLegacyStorageLocator(hasLegacyDb: true),
        isMigratedOverride: () async => true,
        setMigratedOverride: ({required value}) async {
          setMigratedCalled = true;
        },
        loadLegacyAddressesOverride: () async => ['0xabc'],
        loadLegacyDevicesOverride: () async => [
          const FF1Device(
            name: 'FF1 A',
            remoteId: 'remote-a',
            deviceId: 'device-a',
            topicId: 'topic-a',
          ),
        ],
        migrateAddressOverride: (address) async {
          migratedAddresses.add(address);
        },
        migrateDevicesOverride: (devices) async {
          migratedDevices.addAll(devices);
        },
      );

      final result = await service.migrateIfNeeded();

      expect(result.didRun, isFalse);
      expect(result.importedAddresses, 0);
      expect(result.importedDevices, 0);
      expect(setMigratedCalled, isFalse);
      expect(migratedAddresses, isEmpty);
      expect(migratedDevices, isEmpty);
    });

    test('migrates legacy addresses/devices and sets migrated flag', () async {
      final migratedAddresses = <String>[];
      final migratedDevices = <FF1Device>[];
      bool? migratedFlag;

      final service = LegacyDataMigrationService(
        storageLocator: _FakeLegacyStorageLocator(hasLegacyDb: true),
        isMigratedOverride: () async => false,
        setMigratedOverride: ({required value}) async {
          migratedFlag = value;
        },
        loadLegacyAddressesOverride: () async => ['0xabc', '0xdef'],
        loadLegacyDevicesOverride: () async => const [
          FF1Device(
            name: 'FF1 A',
            remoteId: 'remote-a',
            deviceId: 'device-a',
            topicId: 'topic-a',
          ),
          FF1Device(
            name: 'FF1 B',
            remoteId: 'remote-b',
            deviceId: 'device-b',
            topicId: 'topic-b',
          ),
        ],
        migrateAddressOverride: (address) async {
          migratedAddresses.add(address);
        },
        migrateDevicesOverride: (devices) async {
          migratedDevices.addAll(devices);
        },
      );

      final result = await service.migrateIfNeeded();

      expect(result.didRun, isTrue);
      expect(result.importedAddresses, 2);
      expect(result.importedDevices, 2);
      expect(migratedAddresses, ['0xabc', '0xdef']);
      expect(migratedDevices.map((e) => e.deviceId), ['device-a', 'device-b']);
      expect(migratedFlag, isTrue);
    });
  });
}
