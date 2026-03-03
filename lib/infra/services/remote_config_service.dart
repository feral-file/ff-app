import 'dart:convert';
import 'dart:io';

import 'package:app/infra/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final _log = Logger('RemoteConfigService');

/// Fetches and caches remote config (app_update section).
///
/// Cache-first: [getCachedConfig] reads from local file without network.
/// [fetchAndPersist] fetches from server, persists to local, returns config.
class RemoteConfigService {
  /// Creates a [RemoteConfigService].
  RemoteConfigService({
    http.Client? httpClient,
    String? configUrl,
  }) : _httpClient = httpClient ?? http.Client(),
       _configUrl = configUrl ?? AppConfig.remoteConfigUrl;

  final http.Client _httpClient;
  final String _configUrl;

  static const _fileName = 'remote_config_cache.json';

  /// In-memory cache. Populated on first [get] or after [fetchAndPersist].
  Map<String, dynamic>? _cachedConfig;

  Future<File> _cacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  /// Ensures config is loaded. Uses in-memory cache if available.
  Future<Map<String, dynamic>> _ensureConfigLoaded() async {
    if (_cachedConfig != null) return _cachedConfig!;
    _cachedConfig = await getCachedConfig();
    return _cachedConfig!;
  }

  /// Reads cached config from local file. Never blocks on network.
  Future<Map<String, dynamic>> getCachedConfig() async {
    try {
      final file = await _cacheFile();
      if (!file.existsSync()) return {};
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on Object catch (e, stack) {
      _log.warning('Failed to read cached remote config', e, stack);
      return {};
    }
  }

  /// Gets a value by dot-separated path from cached config.
  ///
  /// Reads from in-memory cache (no file I/O after first load). Returns
  /// [defaultValue] if path not found, value is null, or cast fails.
  /// Use [parser] for custom conversion.
  Future<T> get<T>(
    String path,
    T defaultValue, {
    T Function(dynamic)? parser,
  }) async {
    final config = await _ensureConfigLoaded();
    try {
      final keys = path.split('.');
      dynamic current = config;
      for (final key in keys) {
        if (current is! Map || !current.containsKey(key)) {
          return defaultValue;
        }
        current = current[key];
      }
      if (current == null) return defaultValue;
      if (parser != null) return parser(current);
      return current as T;
    } on Object catch (e, stack) {
      _log.warning('RemoteConfigService.get: $path', e, stack);
      return defaultValue;
    }
  }

  /// Fetches from server, persists to local, updates in-memory cache.
  /// On fetch/parse error: returns cached config from file (fail-open).
  Future<Map<String, dynamic>> fetchAndPersist() async {
    try {
      final url = '$_configUrl/ff-app.json';
      final response = await _httpClient.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final cached = await getCachedConfig();
        _cachedConfig = cached;
        return cached;
      }
      final decoded = jsonDecode(response.body);
      final config = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      _cachedConfig = config;
      final file = await _cacheFile();
      await file.writeAsString(jsonEncode(config));
      return config;
    } on Object catch (e, stack) {
      _log.warning('Failed to fetch remote config', e, stack);
      final cached = await getCachedConfig();
      _cachedConfig = cached;
      return cached;
    }
  }
}
