import 'dart:io';

import 'package:app/util/user_agent_utils.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

/// Provides device identity and name for FF1 client (connect request).
class DeviceInfoService {
  DeviceInfoService() : _deviceInfoPlugin = DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfoPlugin;
  static final _log = Logger('DeviceInfoService');

  String _deviceId = '';
  String _deviceName = '';
  String _deviceModel = '';
  String _deviceVendor = '';
  String _deviceOSName = '';
  String _deviceOSVersion = '';
  bool _didInitialized = false;
  final Map<String, String> _appleModelIdentifier = {};

  Future<void> init() async {
    _log.info('[DeviceInfoService] init');
    if (_didInitialized) {
      _log.info('[DeviceInfoService] already initialized');
      return;
    }
    try {
      final device = DeviceInfo.instance;
      _deviceId = await _getDeviceId();
      final deviceInfo = await device.getUserDeviceInfo();
      _deviceName = deviceInfo.name;
      _deviceModel = deviceInfo.model;
      _deviceVendor = deviceInfo.vendor;
      _deviceOSName = deviceInfo.osName;
      _deviceOSVersion = deviceInfo.oSVersion;
    } catch (e) {
      if (_deviceName.isEmpty) {
        _deviceName = 'Feral File App';
      }
      if (_deviceId.isEmpty) {
        _deviceId = const Uuid().v4();
      }
    }
    _didInitialized = true;
    _log.info('[DeviceInfoService] initialized');
  }

  Future<String> _getDeviceId() async {
    if (Platform.isIOS) {
      final ios = await _deviceInfoPlugin.iosInfo;
      return ios.identifierForVendor ?? const Uuid().v4();
    }
    if (Platform.isAndroid) {
      final android = await _deviceInfoPlugin.androidInfo;
      return android.id;
    }
    return const Uuid().v4();
  }

  String get deviceId => _deviceId;

  String get deviceName {
    if (Platform.isAndroid) {
      return '$_deviceVendor $_deviceModel';
    }
    return _mapIphoneIdentifierToModel(_deviceModel);
  }

  String get deviceModel => _deviceModel;
  String get deviceVendor => _deviceVendor;
  String get deviceOSName => _deviceOSName;
  String get deviceOSVersion => _deviceOSVersion;

  String _mapIphoneIdentifierToModel(String identifier) {
    if (_appleModelIdentifier.isNotEmpty) {
      return _appleModelIdentifier[identifier] ?? identifier;
    }
    return iphoneIdentifierCache[identifier] ?? identifier;
  }
}

const Map<String, String> iphoneIdentifierCache = {
  'iPhone1,1': 'iPhone',
  'iPhone1,2': 'iPhone3G',
  'iPhone2,1': 'iPhone3GS',
  'iPhone3,1': 'iPhone4',
  'iPhone3,2': 'iPhone4',
  'iPhone3,3': 'iPhone4',
  'iPhone4,1': 'iPhone4S',
  'iPhone5,1': 'iPhone5',
  'iPhone5,2': 'iPhone5',
  'iPhone5,3': 'iPhone5c',
  'iPhone5,4': 'iPhone5c',
  'iPhone6,1': 'iPhone5s',
  'iPhone6,2': 'iPhone5s',
  'iPhone7,2': 'iPhone6',
  'iPhone7,1': 'iPhone6Plus',
  'iPhone8,1': 'iPhone6s',
  'iPhone8,2': 'iPhone6sPlus',
  'iPhone8,4': 'iPhoneSE',
  'iPhone9,1': 'iPhone7',
  'iPhone9,2': 'iPhone7Plus',
  'iPhone9,3': 'iPhone7',
  'iPhone9,4': 'iPhone7Plus',
  'iPhone10,1': 'iPhone8',
  'iPhone10,2': 'iPhone8Plus',
  'iPhone10,3': 'iPhoneX',
  'iPhone10,4': 'iPhone8',
  'iPhone10,5': 'iPhone8Plus',
  'iPhone10,6': 'iPhoneX',
  'iPhone11,2': 'iPhoneXS',
  'iPhone11,4': 'iPhoneXSMax',
  'iPhone11,6': 'iPhoneXSMax',
  'iPhone11,8': 'iPhoneXR',
  'iPhone12,1': 'iPhone11',
  'iPhone12,3': 'iPhone11Pro',
  'iPhone12,5': 'iPhone11ProMax',
  'iPhone12,8': 'iPhoneSE',
  'iPhone13,1': 'iPhone12mini',
  'iPhone13,2': 'iPhone12',
  'iPhone13,3': 'iPhone12Pro',
  'iPhone13,4': 'iPhone12ProMax',
  'iPhone14,2': 'iPhone13Pro',
  'iPhone14,3': 'iPhone13ProMax',
  'iPhone14,4': 'iPhone13mini',
  'iPhone14,5': 'iPhone13',
  'iPhone14,6': 'iPhoneSE',
  'iPhone15,2': 'iPhone14Pro',
  'iPhone15,3': 'iPhone14Pro Max',
  'iPhone15,4': 'iPhone14',
  'iPhone15,5': 'iPhone14Plus',
  'iPhone16,1': 'iPhone15',
  'iPhone16,2': 'iPhone15Pro',
  'iPhone16,3': 'iPhone15Plus',
  'iPhone16,4': 'iPhone15ProMax',
  'iPhone17,1': 'iPhone16Pro',
  'iPhone17,2': 'iPhone16Pro Max',
  'iPhone17,3': 'iPhone16',
  'iPhone17,4': 'iPhone16Plus',
  'iPhone17,5': 'iPhone16e',
};
