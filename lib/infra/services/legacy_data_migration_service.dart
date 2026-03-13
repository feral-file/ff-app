import 'dart:convert';

import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/infra/services/address_service.dart';
import 'package:app/infra/services/legacy_storage_locator.dart';
import 'package:app/objectbox.g.dart' show AppStateEntity_;
import 'package:hive_flutter/hive_flutter.dart' as hive_flutter;
import 'package:logging/logging.dart';
import 'package:objectbox/objectbox.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Summary of one-time legacy migration results.
class LegacyDataMigrationResult {
  /// Creates a migration result summary.
  const LegacyDataMigrationResult({
    required this.didRun,
    required this.importedAddresses,
    required this.importedDevices,
  });

  /// Whether a migration execution actually ran this startup.
  final bool didRun;

  /// Number of addresses imported into the current app state.
  final int importedAddresses;

  /// Number of FF1 devices imported into ObjectBox.
  final int importedDevices;
}

/// Migrates legacy app data (SQLite + Hive) into current storage layers.
class LegacyDataMigrationService {
  /// Creates a legacy-data migration service.
  LegacyDataMigrationService({
    Box<AppStateEntity>? localConfigBox,
    AddressService? addressService,
    FF1BluetoothDeviceService? bluetoothDeviceService,
    LegacyStorageLocator? storageLocator,
    Logger? logger,
    Future<bool> Function()? isMigratedOverride,
    Future<void> Function({required bool value})? setMigratedOverride,
    Future<List<String>> Function()? loadLegacyAddressesOverride,
    Future<List<FF1Device>> Function()? loadLegacyDevicesOverride,
    Future<void> Function(String address)? migrateAddressOverride,
    Future<void> Function(List<FF1Device> devices)? migrateDevicesOverride,
  }) : _localConfigBox = localConfigBox,
       _addressService = addressService,
       _bluetoothDeviceService = bluetoothDeviceService,
       _storageLocator = storageLocator ?? LegacyStorageLocator(),
       _log = logger ?? Logger('LegacyDataMigrationService'),
       _isMigratedOverride = isMigratedOverride,
       _setMigratedOverride = setMigratedOverride,
       _loadLegacyAddressesOverride = loadLegacyAddressesOverride,
       _loadLegacyDevicesOverride = loadLegacyDevicesOverride,
       _migrateAddressOverride = migrateAddressOverride,
       _migrateDevicesOverride = migrateDevicesOverride;

  static const _appScope = 'app';
  final Box<AppStateEntity>? _localConfigBox;
  final AddressService? _addressService;
  final FF1BluetoothDeviceService? _bluetoothDeviceService;
  final LegacyStorageLocator _storageLocator;
  final Logger _log;
  final Future<bool> Function()? _isMigratedOverride;
  final Future<void> Function({required bool value})? _setMigratedOverride;
  final Future<List<String>> Function()? _loadLegacyAddressesOverride;
  final Future<List<FF1Device>> Function()? _loadLegacyDevicesOverride;
  final Future<void> Function(String address)? _migrateAddressOverride;
  final Future<void> Function(List<FF1Device> devices)? _migrateDevicesOverride;

  /// Returns true when legacy SQLite files exist (treated as onboarded user).
  Future<bool> hasLegacyOnboardedData() {
    return _storageLocator.hasLegacySqliteDatabase();
  }

  /// Runs one-time migration guarded by ObjectBox `isMigrated` flag.
  Future<LegacyDataMigrationResult> migrateIfNeeded() async {
    if (await _isMigrated()) {
      return const LegacyDataMigrationResult(
        didRun: false,
        importedAddresses: 0,
        importedDevices: 0,
      );
    }

    var importedAddresses = 0;
    var importedDevices = 0;
    try {
      final addresses = await _loadLegacyAddressesWithOverrides();
      importedAddresses = await _migrateAddresses(addresses);

      final devices = await _loadLegacyDevicesWithOverrides();
      importedDevices = await _migrateDevices(devices);

      await _setMigrated(value: true);
      _log.info(
        'Legacy migration done. '
        'addresses=$importedAddresses, devices=$importedDevices',
      );
      return LegacyDataMigrationResult(
        didRun: true,
        importedAddresses: importedAddresses,
        importedDevices: importedDevices,
      );
    } on Object catch (e, st) {
      _log.warning('Legacy migration failed', e, st);
      rethrow;
    }
  }

  /// Returns true when migration should run in current startup context.
  Future<bool> shouldRunMigration() async {
    if (!await hasLegacyOnboardedData()) {
      return false;
    }
    return !(await _isMigrated());
  }

  Future<int> _migrateAddresses(List<String> addresses) async {
    var imported = 0;
    for (final address in addresses) {
      try {
        if (_migrateAddressOverride != null) {
          await _migrateAddressOverride.call(address);
        } else {
          await _addressService!.addAddress(
            walletAddress: WalletAddress(
              address: address,
              createdAt: DateTime.now().toUtc(),
              name: _shortAddress(address),
            ),
          );
        }
        imported++;
      } on Object catch (e, st) {
        _log.warning('Failed to migrate legacy address: $address', e, st);
      }
    }
    return imported;
  }

  Future<int> _migrateDevices(List<FF1Device> devices) async {
    if (devices.isEmpty) {
      return 0;
    }

    if (_migrateDevicesOverride != null) {
      await _migrateDevicesOverride.call(devices);
      return devices.length;
    }

    for (final device in devices) {
      await _bluetoothDeviceService!.putDevice(device);
    }

    await _bluetoothDeviceService!.setActiveDevice(devices.first.deviceId);
    return devices.length;
  }

  Future<bool> _isMigrated() {
    final override = _isMigratedOverride;
    if (override != null) {
      return override();
    }
    final row = _findAppStateRow();
    if (row == null) {
      return Future.value(false);
    }
    return Future.value(row.isMigrated);
  }

  Future<void> _setMigrated({required bool value}) {
    final override = _setMigratedOverride;
    if (override != null) {
      return override(value: value);
    }
    final nowUs = DateTime.now().toUtc().microsecondsSinceEpoch;
    final existing = _findAppStateRow();
    final row = AppStateEntity(
      feedCacheDurationSeconds: existing?.feedCacheDurationSeconds ?? 86400,
      feedLastUpdatedAtUs: existing?.feedLastUpdatedAtUs ?? 1672531200000000,
      hasSeenOnboarding: existing?.hasSeenOnboarding ?? false,
      hasSeenPlayToFf1Tooltip: existing?.hasSeenPlayToFf1Tooltip ?? false,
      isMigrated: value,
      updatedAtUs: nowUs,
    )..id = existing?.id ?? 0;
    if (existing != null) {
      row.globalLastRefreshEpochUs = existing.globalLastRefreshEpochUs;
    }
    _localConfigBox!.put(row);
    return Future.value();
  }

  AppStateEntity? _findAppStateRow() {
    final query = _localConfigBox!
        .query(AppStateEntity_.scope.equals(_appScope))
        .build();
    final row = query.findFirst();
    query.close();
    return row;
  }

  Future<List<String>> _loadLegacyAddressesWithOverrides() async {
    final override = _loadLegacyAddressesOverride;
    if (override != null) {
      return override();
    }
    return _loadLegacyAddresses();
  }

  Future<List<FF1Device>> _loadLegacyDevicesWithOverrides() async {
    final override = _loadLegacyDevicesOverride;
    if (override != null) {
      return override();
    }
    return _loadLegacyDevicesFromHive();
  }

  Future<List<String>> _loadLegacyAddresses() async {
    final sqlitePaths = await _storageLocator.findLegacySqlitePaths();
    for (final path in sqlitePaths) {
      final addresses = _readPersonalAddressesFromSqlite(path);
      if (addresses.isNotEmpty) {
        _log.info(
          'Loaded ${addresses.length} address(es) from legacy SQLite: $path',
        );
        return addresses;
      }
    }
    return const [];
  }

  List<String> _readPersonalAddressesFromSqlite(String dbPath) {
    sqlite3.Database? db;
    try {
      db = sqlite3.sqlite3.open(dbPath, mode: sqlite3.OpenMode.readOnly);
      const sql = '''
        SELECT DISTINCT owner_address AS migrated_address
        FROM playlists
        WHERE owner_address IS NOT NULL
          AND TRIM(owner_address) != ''
          AND type = 1
      ''';

      final rows = db.select(sql);
      return rows
          .map((row) => row['migrated_address'] as String?)
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } on Object {
      return const [];
    } finally {
      db?.dispose();
    }
  }

  Future<List<FF1Device>> _loadLegacyDevicesFromHive() async {
    final devices = await _readHiveDevices();
    if (devices.isNotEmpty) {
      _log.info('Loaded ${devices.length} FF1 device(s) from legacy Hive.');
    }
    return devices;
  }

  Future<List<FF1Device>> _readHiveDevices() async {
    final box = await _openLegacyHiveBox();
    if (box == null) {
      return const [];
    }
    try {
      final results = <FF1Device>[];
      for (final key in box.keys) {
        final keyString = key.toString();
        if (!keyString.contains('.common.db.ff_device.')) {
          continue;
        }
        final raw = box.get(keyString);
        if (raw == null || raw.isEmpty) {
          continue;
        }
        final device = _parseLegacyHiveDevice(raw);
        if (device != null) {
          results.add(device);
        }
      }

      final deduped = <String, FF1Device>{};
      for (final device in results) {
        deduped[device.deviceId] = device;
      }
      return deduped.values.toList(growable: false);
    } on Object {
      return const [];
    } finally {
      await box.close();
      await hive_flutter.Hive.close();
    }
  }

  Future<hive_flutter.Box<String>?> _openLegacyHiveBox() async {
    try {
      await hive_flutter.Hive.initFlutter();
      return hive_flutter.Hive.openBox<String>('app_storage');
    } on Object catch (e, st) {
      _log.warning('Failed to open legacy Hive app_storage box', e, st);
      return null;
    }
  }

  FF1Device? _parseLegacyHiveDevice(String jsonString) {
    try {
      final raw = jsonDecode(jsonString);
      if (raw is! Map<String, dynamic>) {
        return null;
      }

      final name = (raw['name'] as String? ?? '').trim();
      final remoteId = (raw['remoteID'] as String? ?? '').trim();
      final topicId = (raw['topicId'] as String? ?? '').trim();
      final deviceId =
          (raw['deviceId'] as String? ?? raw['name'] as String? ?? '').trim();
      final branchName =
          (raw['branchName'] as String? ?? 'release').trim().isEmpty
          ? 'release'
          : (raw['branchName'] as String? ?? 'release').trim();

      if (remoteId.isEmpty || deviceId.isEmpty) {
        return null;
      }

      return FF1Device(
        name: name.isEmpty ? deviceId : name,
        remoteId: remoteId,
        topicId: topicId,
        deviceId: deviceId,
        branchName: branchName,
      );
    } on Object {
      return null;
    }
  }

  String _shortAddress(String address) {
    if (address.length <= 10) {
      return address;
    }
    return '${address.substring(0, 6)}...'
        '${address.substring(address.length - 4)}';
  }
}
