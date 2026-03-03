import 'dart:convert';
import 'dart:io';

import 'package:app/infra/services/remote_config_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../test_helpers/fake_path_provider.dart';

void main() {
  late String testDir;

  setUpAll(() {
    testDir = Directory.systemTemp.createTempSync().path;
    PathProviderPlatform.instance = FakePathProviderPlatform(testDir);
  });

  group('RemoteConfigService', () {
    test('getCachedConfig returns empty map when file does not exist', () async {
      final service = RemoteConfigService(
        configUrl: 'https://example.com/config.json',
      );

      final config = await service.getCachedConfig();

      expect(config, isEmpty);
    });

    test('fetchAndPersist fetches and persists config', () async {
      const expectedConfig = {
        'app_update': {
          'ios': {'required_version': '1.0.5', 'link': 'https://apple.com'},
          'android': {
            'required_version': '1.0.5',
            'link': 'https://play.google.com',
          },
        },
      };

      final client = _MockHttpClient((request) async {
        return http.Response(jsonEncode(expectedConfig), 200);
      });

      final service = RemoteConfigService(
        httpClient: client,
        configUrl: 'https://example.com/config.json',
      );

      final config = await service.fetchAndPersist();

      expect(config, expectedConfig);

      // Verify persisted: getCachedConfig should return same
      final cached = await service.getCachedConfig();
      expect(cached, expectedConfig);
    });

    test('get returns value by dot-separated path from cache', () async {
      const expectedConfig = {
        'app_update': {
          'ios': {
            'required_version': '1.0.5',
            'link': 'https://apps.apple.com/app',
          },
          'android': {
            'required_version': '1.0.6',
            'link': 'https://play.google.com/app',
          },
        },
      };

      final client = _MockHttpClient((_) async {
        return http.Response(jsonEncode(expectedConfig), 200);
      });

      final service = RemoteConfigService(
        httpClient: client,
        configUrl: 'https://example.com/config.json',
      );

      await service.fetchAndPersist();

      expect(
        await service.get<String>('app_update.ios.required_version', ''),
        '1.0.5',
      );
      expect(
        await service.get<String>('app_update.android.link', ''),
        'https://play.google.com/app',
      );
      expect(
        await service.get<String>('app_update.ios.missing', 'default'),
        'default',
      );
      expect(
        await service.get<int>('missing.section', 0),
        0,
      );
    });

    test('fetchAndPersist returns cached config on non-2xx response', () async {
      // First populate cache
      const cachedConfig = {'app_update': {'ios': {'required_version': '1.0.0'}}};
      final cacheFile = File('$testDir/remote_config_cache.json');
      await cacheFile.writeAsString(jsonEncode(cachedConfig));

      final client = _MockHttpClient((_) async => http.Response('error', 404));
      final service = RemoteConfigService(
        httpClient: client,
        configUrl: 'https://example.com/config.json',
      );

      final config = await service.fetchAndPersist();

      expect(config, cachedConfig);
    });
  });
}

class _MockHttpClient extends http.BaseClient {
  _MockHttpClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}
