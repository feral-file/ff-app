import 'package:app/infra/services/force_update_service.dart';
import 'package:app/infra/services/remote_config_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  group('ForceUpdateService.checkForUpdate', () {
    test('returns VersionInfo when current < required', () async {
      final rc = _FakeRemoteConfigService({
        'app_update': {
          'ios': {
            'required_version': '1.0.5',
            'link': 'https://apps.apple.com/app',
          },
          'android': {
            'required_version': '1.0.5',
            'link': 'https://play.google.com/app',
          },
        },
      });

      final service = ForceUpdateService(
        remoteConfigService: rc,
        packageInfo: _FakePackageInfo(version: '1.0.0', buildNumber: '1'),
      );

      final result = await service.checkForUpdate(forceCheck: true);

      expect(result, isNotNull);
      expect(result!.requiredVersion, '1.0.5');
      expect(result.link, isNotEmpty);
    });

    test('returns null when current >= required', () async {
      final rc = _FakeRemoteConfigService({
        'app_update': {
          'ios': {
            'required_version': '1.0.5',
            'link': 'https://apps.apple.com/app',
          },
          'android': {
            'required_version': '1.0.5',
            'link': 'https://play.google.com/app',
          },
        },
      });

      final service = ForceUpdateService(
        remoteConfigService: rc,
        packageInfo: _FakePackageInfo(version: '1.0.5', buildNumber: '10'),
      );

      final result = await service.checkForUpdate(forceCheck: true);

      expect(result, isNull);
    });

    test('returns null when app_update is missing', () async {
      final rc = _FakeRemoteConfigService({});

      final service = ForceUpdateService(
        remoteConfigService: rc,
        packageInfo: _FakePackageInfo(version: '1.0.0', buildNumber: '1'),
      );

      final result = await service.checkForUpdate(forceCheck: true);

      expect(result, isNull);
    });

    test('returns null when platform config is missing', () async {
      final rc = _FakeRemoteConfigService({
        'app_update': {
          'ios': <String, dynamic>{},
          'android': <String, dynamic>{},
        },
      });

      final service = ForceUpdateService(
        remoteConfigService: rc,
        packageInfo: _FakePackageInfo(version: '1.0.0', buildNumber: '1'),
      );

      final result = await service.checkForUpdate(forceCheck: true);

      expect(result, isNull);
    });
  });
}

/// Fake [RemoteConfigService] that returns values from a fixed map.
class _FakeRemoteConfigService extends RemoteConfigService {
  _FakeRemoteConfigService(this._config) : super(configUrl: '');
  final Map<String, dynamic> _config;

  @override
  Future<Map<String, dynamic>> getCachedConfig() async => _config;
}

class _FakePackageInfo implements PackageInfo {
  _FakePackageInfo({
    required this.version,
    required this.buildNumber,
    this.appName = 'app',
    this.packageName = 'com.feralfile.app',
  });

  @override
  final String appName;

  @override
  final String packageName;

  @override
  final String version;

  @override
  final String buildNumber;

  @override
  final String buildSignature = '';

  @override
  final DateTime? installTime = null;

  @override
  final String? installerStore = null;

  @override
  final DateTime? updateTime = null;

  @override
  Map<String, dynamic> get data => {
    'appName': appName,
    'packageName': packageName,
    'version': version,
    'buildNumber': buildNumber,
  };
}
