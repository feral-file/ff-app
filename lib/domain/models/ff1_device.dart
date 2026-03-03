import 'dart:convert';

import 'package:app/domain/models/base_object.dart';
import 'package:app/domain/models/models.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// FF1 device model (Bluetooth-connected device)
///
/// Represents a physical FF1 device that can be paired and controlled
/// via Bluetooth. This is a domain model independent of Flutter framework.
class FF1Device implements BaseObject {
  /// Creates a FF1 device.
  const FF1Device({
    required this.name,
    required this.remoteId,
    required this.deviceId,
    required this.topicId,
    this.branchName = 'release',
  });

  /// Creates a FF1 device from JSON.
  factory FF1Device.fromJson(Map<String, dynamic> json) {
    return FF1Device(
      name: json['name'] as String,
      remoteId: json['remoteId'] as String,
      deviceId: json['deviceId'] as String? ?? json['name'] as String,
      topicId: json['topicId'] as String,
      branchName: json['branchName'] as String? ?? 'release',
    );
  }

  /// Creates a FF1 device from BluetoothDevice.
  factory FF1Device.fromBluetoothDeviceAndDeviceInfo(
    BluetoothDevice blDevice,
    FF1DeviceInfo deviceInfo,
  ) {
    return FF1Device(
      name: deviceInfo.name,
      deviceId: deviceInfo.deviceId,
      topicId: deviceInfo.topicId,
      branchName: deviceInfo.branchName,
      remoteId: blDevice.remoteId.str,
    );
  }

  /// User-friendly name for the device
  final String name;

  /// Bluetooth remote ID (MAC address or UUID depending on platform)
  final String remoteId;

  /// Unique device identifier (shown on FF1 screen)
  final String deviceId;

  /// Topic ID for cloud/WebSocket communication (obtained after WiFi setup)
  final String topicId;

  /// Release branch (release, demo, qemu, etc.)
  final String branchName;

  Map<String, dynamic> toJson() => {
    'name': name,
    'remoteId': remoteId,
    'deviceId': deviceId,
    'topicId': topicId,
    'branchName': branchName,
  };

  FF1Device copyWith({
    String? name,
    String? remoteId,
    String? deviceId,
    String? topicId,
    String? branchName,
  }) {
    return FF1Device(
      name: name ?? this.name,
      remoteId: remoteId ?? this.remoteId,
      deviceId: deviceId ?? this.deviceId,
      topicId: topicId ?? this.topicId,
      branchName: branchName ?? this.branchName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FF1Device &&
        other.name == name &&
        other.remoteId == remoteId &&
        other.deviceId == deviceId &&
        other.topicId == topicId &&
        other.branchName == branchName;
  }

  @override
  int get hashCode => Object.hash(
    name,
    remoteId,
    deviceId,
    topicId,
    branchName,
  );

  @override
  String toString() =>
      'FF1Device(name: $name, deviceId: $deviceId, '
      'remoteId: $remoteId, topicId: $topicId, branch: $branchName)';

  /// Storage key for persistence (using deviceId as key)
  String get storageKey => deviceId;

  /// Storage value (JSON encoded)
  String get storageValue => jsonEncode(toJson());

  @override
  String get key => deviceId;

  @override
  String get value => storageValue;

  @override
  Map<String, String> get toKeyValue => {
    'key': key,
    'value': value,
  };
}

/// Extension methods for FF1Device
extension FF1DeviceExt on FF1Device {
  /// Whether device is on release branch
  bool get isReleaseBranch => branchName == 'release';

  /// Whether device is on demo branch
  bool get isDemoBranch => branchName == 'demo';

  /// Whether device is QEMU (emulator)
  bool get isQEMU => branchName.toLowerCase().contains('qemu');

  /// Whether device has cloud connectivity (topicId set)
  bool get hasCloudConnection => topicId.isNotEmpty;

  /// Convert to BluetoothDevice for flutter_blue_plus operations
  BluetoothDevice toBluetoothDevice() => BluetoothDevice.fromId(remoteId);
}
