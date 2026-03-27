import 'dart:convert';

import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/objectbox.g.dart' show FF1BluetoothDeviceEntity_;
import 'package:logging/logging.dart';
import 'package:objectbox/objectbox.dart';

/// Service for persisting and managing FF1 Bluetooth devices using ObjectBox.
///
/// Handles all database operations for connected devices including:
/// - Adding/updating devices
/// - Removing devices
/// - Querying devices by various criteria
/// - Managing active device state
/// - Tracking connection states
class FF1BluetoothDeviceService {
  /// Creates a FF1BluetoothDeviceService.
  FF1BluetoothDeviceService(this._box) : _log = Logger('FF1BluetoothDeviceService');

  final Box<FF1BluetoothDeviceEntity> _box;
  final Logger _log;

  /// Stream of all devices; emits whenever the ObjectBox entity changes.
  ///
  /// Use this instead of [getAllDevices] when you need reactive updates
  /// (e.g. migration, add/remove device) without manual invalidate.
  Stream<List<FF1Device>> watchAllDevices() {
    // Avoid missing change events between the initial synchronous read and the
    // watch subscription. QueryBuilder.watch(triggerImmediately: true)
    // guarantees the first emission occurs after the listener is attached.
    final queryBuilder = _box.query();
    return queryBuilder.watch(triggerImmediately: true).map(
          (query) => query.find().map(_entityToDomain).toList(),
        );
  }

  /// Get all stored Bluetooth devices
  List<FF1Device> getAllDevices() {
    try {
      final entities = _box.getAll();
      return entities.map(_entityToDomain).toList();
    } catch (e, stack) {
      _log.severe('Failed to get all devices', e, stack);
      rethrow;
    }
  }

  /// Get device by device ID
  FF1Device? getDeviceById(String deviceId) {
    try {
      final query = _box
          .query(FF1BluetoothDeviceEntity_.deviceId.equals(deviceId))
          .build();
      final results = query.find();
      query.close();

      if (results.isEmpty) return null;
      return _entityToDomain(results.first);
    } catch (e, stack) {
      _log.severe('Failed to get device by ID: $deviceId', e, stack);
      rethrow;
    }
  }

  /// Get device by Bluetooth remote ID
  FF1Device? getDeviceByRemoteId(String remoteId) {
    try {
      final query = _box
          .query(FF1BluetoothDeviceEntity_.remoteId.equals(remoteId))
          .build();
      final results = query.find();
      query.close();

      if (results.isEmpty) return null;
      return _entityToDomain(results.first);
    } catch (e, stack) {
      _log.severe('Failed to get device by remote ID: $remoteId', e, stack);
      rethrow;
    }
  }

  /// Stream of the active device; emits whenever the ObjectBox entity changes.
  ///
  /// Use this instead of [getActiveDevice] when you need reactive updates
  /// (e.g. migration, setActiveDevice) without manual invalidate.
  Stream<FF1Device?> watchActiveDevice() {
    // Avoid missing change events between the initial synchronous read and the
    // watch subscription. QueryBuilder.watch(triggerImmediately: true)
    // guarantees the first emission occurs after the listener is attached.
    final queryBuilder = _box.query(FF1BluetoothDeviceEntity_.isActive.equals(true));
    return queryBuilder.watch(triggerImmediately: true).map((query) {
          final results = query.find();
          return results.isEmpty ? null : _entityToDomain(results.first);
        });
  }

  /// Get the currently active device
  FF1Device? getActiveDevice() {
    try {
      final query = _box
          .query(FF1BluetoothDeviceEntity_.isActive.equals(true))
          .build();
      final results = query.find();
      query.close();

      if (results.isEmpty) return null;
      return _entityToDomain(results.first);
    } catch (e, stack) {
      _log.severe('Failed to get active device', e, stack);
      rethrow;
    }
  }

  /// Add or update a device
  ///
  /// Removes all existing entities with the same [device.deviceId] before
  /// inserting the new one to avoid duplicates and ensure topicId updates
  /// are persisted correctly.
  Future<void> putDevice(FF1Device device) async {
    try {
      final now = DateTime.now().microsecondsSinceEpoch;

      // Remove all old entities with the same deviceId
      final query = _box
          .query(FF1BluetoothDeviceEntity_.deviceId.equals(device.deviceId))
          .build();
      final existingList = query.find();
      int? preservedCreatedAtUs;
      if (existingList.isNotEmpty) {
        preservedCreatedAtUs = existingList.first.createdAtUs;
        for (final entity in existingList) {
          _box.remove(entity.id);
        }
      }
      query.close();

      final entity = FF1BluetoothDeviceEntity(
        deviceId: device.deviceId,
        remoteId: device.remoteId,
        name: device.name,
        topicId: device.topicId,
        branchName: device.branchName,
        createdAtUs: preservedCreatedAtUs ?? now,
        updatedAtUs: now,
      );

      _box.put(entity);
      _log.info('Device added/updated: ${device.deviceId}');
    } catch (e, stack) {
      _log.severe('Failed to put device: ${device.deviceId}', e, stack);
      rethrow;
    }
  }

  /// Set a device as the active/casting device
  Future<void> setActiveDevice(String deviceId) async {
    try {
      // Clear previous active device
      final query = _box
          .query(FF1BluetoothDeviceEntity_.isActive.equals(true))
          .build();
      final previousActive = query.find();
      query.close();

      for (final device in previousActive) {
        device.isActive = false;
        _box.put(device);
      }

      // Set new active device
      final query2 = _box
          .query(FF1BluetoothDeviceEntity_.deviceId.equals(deviceId))
          .build();
      final results = query2.find();
      query2.close();

      if (results.isNotEmpty) {
        results.first.isActive = true;
        _box.put(results.first);
        _log.info('Active device set to: $deviceId');
      }
    } catch (e, stack) {
      _log.severe('Failed to set active device: $deviceId', e, stack);
      rethrow;
    }
  }

  /// Update device connection state
  /// state: 0 = disconnected, 1 = connected, 2 = connecting
  Future<void> updateConnectionState(String deviceId, int state) async {
    try {
      final query = _box
          .query(FF1BluetoothDeviceEntity_.deviceId.equals(deviceId))
          .build();
      final results = query.find();
      query.close();

      if (results.isEmpty) {
        _log.warning('Device not found: $deviceId');
        return;
      }

      final device = results.first;
      device.connectionState = state;
      device.updatedAtUs = DateTime.now().microsecondsSinceEpoch;

      if (state == 1) {
        // connected
        device.failedConnectionAttempts = 0;
        device.lastConnectionAttemptUs = DateTime.now().microsecondsSinceEpoch;
      }

      _box.put(device);
      _log.info('Connection state updated for $deviceId: $state');
    } catch (e, stack) {
      _log.severe('Failed to update connection state for $deviceId', e, stack);
      rethrow;
    }
  }

  /// Record a failed connection attempt
  Future<void> recordFailedConnection(String deviceId) async {
    try {
      final query = _box
          .query(FF1BluetoothDeviceEntity_.deviceId.equals(deviceId))
          .build();
      final results = query.find();
      query.close();

      if (results.isEmpty) {
        _log.warning('Device not found: $deviceId');
        return;
      }

      final device = results.first;
      device.failedConnectionAttempts++;
      device.lastConnectionAttemptUs = DateTime.now().microsecondsSinceEpoch;
      device.updatedAtUs = DateTime.now().microsecondsSinceEpoch;

      _box.put(device);
      _log.info(
        'Failed connection recorded for $deviceId (attempts: ${device.failedConnectionAttempts})',
      );
    } catch (e, stack) {
      _log.severe('Failed to record failed connection for $deviceId', e, stack);
      rethrow;
    }
  }

  /// Update device topic ID (cloud connectivity info)
  Future<void> updateTopicId(String deviceId, String topicId) async {
    try {
      final query = _box
          .query(FF1BluetoothDeviceEntity_.deviceId.equals(deviceId))
          .build();
      final results = query.find();
      query.close();

      if (results.isEmpty) {
        _log.warning('Device not found: $deviceId');
        return;
      }

      final device = results.first;
      device.topicId = topicId;
      device.updatedAtUs = DateTime.now().microsecondsSinceEpoch;

      _box.put(device);
      _log.info('Topic ID updated for $deviceId');
    } catch (e, stack) {
      _log.severe('Failed to update topic ID for $deviceId', e, stack);
      rethrow;
    }
  }

  /// Store additional metadata for a device
  Future<void> updateMetadata(
    String deviceId,
    Map<String, dynamic> metadata,
  ) async {
    try {
      final query = _box
          .query(FF1BluetoothDeviceEntity_.deviceId.equals(deviceId))
          .build();
      final results = query.find();
      query.close();

      if (results.isEmpty) {
        _log.warning('Device not found: $deviceId');
        return;
      }

      final device = results.first;
      device.metadataJson = jsonEncode(metadata);
      device.updatedAtUs = DateTime.now().microsecondsSinceEpoch;

      _box.put(device);
      _log.info('Metadata updated for $deviceId');
    } catch (e, stack) {
      _log.severe('Failed to update metadata for $deviceId', e, stack);
      rethrow;
    }
  }

  /// Remove a device from storage
  Future<void> removeDevice(String deviceId) async {
    try {
      final query = _box
          .query(FF1BluetoothDeviceEntity_.deviceId.equals(deviceId))
          .build();
      final results = query.find();
      query.close();

      if (results.isEmpty) {
        _log.warning('Device not found: $deviceId');
        return;
      }

      _box.remove(results.first.id);
      _log.info('Device removed: $deviceId');
    } catch (e, stack) {
      _log.severe('Failed to remove device: $deviceId', e, stack);
      rethrow;
    }
  }

  /// Remove all devices from storage
  Future<void> removeAllDevices() async {
    try {
      _box.removeAll();
      _log.info('All devices removed');
    } catch (e, stack) {
      _log.severe('Failed to remove all devices', e, stack);
      rethrow;
    }
  }

  /// Convert entity to domain model
  FF1Device _entityToDomain(FF1BluetoothDeviceEntity entity) {
    return FF1Device(
      name: entity.name,
      remoteId: entity.remoteId,
      deviceId: entity.deviceId,
      topicId: entity.topicId,
      branchName: entity.branchName,
    );
  }
}
