import 'package:app/domain/extensions/ff1_device_info_ext.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FF1DeviceInfo.fromEncodedPath', () {
    test('single segment uses defaults for device metadata', () {
      final info = FF1DeviceInfo.fromEncodedPath('topic-123');
      expect(info.deviceId, 'FF1');
      expect(info.topicId, 'topic-123');
      expect(info.isConnectedToInternet, false);
      expect(info.branchName, 'release');
      expect(info.version, '1.0.0');
    });

    test('multiple pipe segments maps all fields', () {
      final info = FF1DeviceInfo.fromEncodedPath(
        'MyDevice|tid|true|beta|2.0.0',
      );
      expect(info.deviceId, 'MyDevice');
      expect(info.topicId, 'tid');
      expect(info.isConnectedToInternet, true);
      expect(info.branchName, 'beta');
      expect(info.version, '2.0.0');
    });

    test('decodes URI-encoded path', () {
      final info = FF1DeviceInfo.fromEncodedPath('FF1%7Ctopic');
      expect(info.deviceId, 'FF1');
      expect(info.topicId, 'topic');
    });
  });

  group('FF1DeviceInfo.fromDeeplink', () {
    test('returns null when prefix is unknown', () {
      expect(FF1DeviceInfo.fromDeeplink('https://example.com/device_connect/x'),
          isNull);
    });

    test('parses feralfile scheme and strips leading slash', () {
      final info = FF1DeviceInfo.fromDeeplink(
        'feralfile://device_connect/MyId|top|false|release|1',
      );
      expect(info, isNotNull);
      expect(info!.deviceId, 'MyId');
      expect(info.topicId, 'top');
      expect(info.isConnectedToInternet, false);
    });

    test('parses https universal link', () {
      final info = FF1DeviceInfo.fromDeeplink(
        'https://link.feralfile.com/device_connect/x|y',
      );
      expect(info, isNotNull);
      expect(info!.deviceId, 'x');
      expect(info.topicId, 'y');
    });
  });

  group('FF1DeviceInfo.isPortalAllSet', () {
    test('true when topic is non-empty and device is online', () {
      const info = FF1DeviceInfo(
        deviceId: 'd',
        topicId: 't1',
        isConnectedToInternet: true,
        branchName: 'release',
        version: '1',
      );
      expect(info.isPortalAllSet, isTrue);
    });

    test('false when topic is empty', () {
      const info = FF1DeviceInfo(
        deviceId: 'd',
        topicId: '',
        isConnectedToInternet: true,
        branchName: 'release',
        version: '1',
      );
      expect(info.isPortalAllSet, isFalse);
    });

    test('false when not connected to internet', () {
      const info = FF1DeviceInfo(
        deviceId: 'd',
        topicId: 't1',
        isConnectedToInternet: false,
        branchName: 'release',
        version: '1',
      );
      expect(info.isPortalAllSet, isFalse);
    });
  });
}
