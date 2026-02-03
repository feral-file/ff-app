import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

/// Persistence store for feed cache configuration.
///
/// This store manages cache policy configuration for DP1 feed services:
/// - Last refresh time per baseUrl
/// - Cache duration (TTL)
/// - Global content last-updated timestamp
///
/// File format:
/// ```json
/// {
///   "lastRefreshTimeByUrl": {"https://feed.example": "2024-01-01T00:00:00.000Z"},
///   "cacheDurationSeconds": 86400,
///   "lastFeedUpdatedAt": "2023-01-01T00:00:00.000Z"
/// }
/// ```
class FeedConfigStore {
  /// Creates a [FeedConfigStore].
  FeedConfigStore({
    required Future<Directory> Function() documentsDirFactory,
    Logger? logger,
  })  : _documentsDirFactory = documentsDirFactory,
        _log = logger ?? Logger('FeedConfigStore');

  static const _fileName = 'feed_config.json';
  static const _lastRefreshTimeByUrlKey = 'lastRefreshTimeByUrl';
  static const _cacheDurationSecondsKey = 'cacheDurationSeconds';
  static const _lastFeedUpdatedAtKey = 'lastFeedUpdatedAt';

  static const _defaultCacheDurationSeconds = 86400; // 1 day
  static final _defaultLastFeedUpdatedAt = DateTime(2023);

  final Future<Directory> Function() _documentsDirFactory;
  final Logger _log;
  final Lock _lock = Lock();

  @visibleForTesting

  /// Resolves the config file path.
  Future<File> resolveFile() async {
    final dir = await _documentsDirFactory();
    return File(p.join(dir.path, _fileName));
  }

  /// Reads the config file.
  Future<Map<String, dynamic>> _readConfig() async {
    return _lock.synchronized(() async {
      try {
        final file = await resolveFile();
        if (!file.existsSync()) {
          return <String, dynamic>{};
        }
        final raw = file.readAsStringSync();
        if (raw.trim().isEmpty) {
          return <String, dynamic>{};
        }
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          _log.warning('Invalid JSON shape in $_fileName, resetting.');
          return <String, dynamic>{};
        }
        return decoded;
      } on Exception catch (e, stack) {
        _log.warning(
          'Failed to read $_fileName, returning empty config.',
          e,
          stack,
        );
        return <String, dynamic>{};
      }
    });
  }

  /// Writes the config file.
  Future<void> _writeConfig(Map<String, dynamic> config) async {
    return _lock.synchronized(() async {
      final file = await resolveFile();
      file.writeAsStringSync(jsonEncode(config));
    });
  }

  /// Gets the last refresh time for a specific baseUrl.
  ///
  /// Returns [DateTime(1970)] if no refresh time is recorded.
  Future<DateTime> getLastRefreshTime(String baseUrl) async {
    final config = await _readConfig();
    final map = config[_lastRefreshTimeByUrlKey] as Map<String, dynamic>?;
    if (map == null) {
      return DateTime(1970);
    }
    final timeStr = map[baseUrl] as String?;
    if (timeStr == null) {
      return DateTime(1970);
    }
    try {
      return DateTime.parse(timeStr);
    } on FormatException {
      return DateTime(1970);
    }
  }

  /// Sets the last refresh time for a specific baseUrl.
  Future<void> setLastRefreshTime(String baseUrl, DateTime time) async {
    final config = await _readConfig();
    final map = config[_lastRefreshTimeByUrlKey] as Map<String, dynamic>? ??
        <String, dynamic>{};
    map[baseUrl] = time.toIso8601String();
    config[_lastRefreshTimeByUrlKey] = map;
    await _writeConfig(config);
  }

  /// Gets the cache duration (TTL).
  ///
  /// Defaults to 1 day (86400 seconds).
  Future<Duration> getCacheDuration() async {
    final config = await _readConfig();
    final seconds = config[_cacheDurationSecondsKey] as int? ??
        _defaultCacheDurationSeconds;
    return Duration(seconds: seconds);
  }

  /// Sets the cache duration (TTL).
  Future<void> setCacheDuration(Duration duration) async {
    final config = await _readConfig();
    config[_cacheDurationSecondsKey] = duration.inSeconds;
    await _writeConfig(config);
  }

  /// Gets the global content last-updated timestamp.
  ///
  /// Defaults to 2023-01-01 if not set.
  Future<DateTime> getLastFeedUpdatedAt() async {
    final config = await _readConfig();
    final timeStr = config[_lastFeedUpdatedAtKey] as String?;
    if (timeStr == null) {
      return _defaultLastFeedUpdatedAt;
    }
    try {
      return DateTime.parse(timeStr);
    } on FormatException {
      return _defaultLastFeedUpdatedAt;
    }
  }

  /// Sets the global content last-updated timestamp.
  Future<void> setLastFeedUpdatedAt(DateTime time) async {
    final config = await _readConfig();
    config[_lastFeedUpdatedAtKey] = time.toIso8601String();
    await _writeConfig(config);
  }
}

/// Provider for [FeedConfigStore].
///
/// Tests should override this provider with an in-memory fake.
final feedConfigStoreProvider = Provider<FeedConfigStore>((ref) {
  return FeedConfigStore(
    documentsDirFactory: getApplicationDocumentsDirectory,
    logger: Logger('FeedConfigStore'),
  );
});
