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
  }) : _documentsDirFactory = documentsDirFactory,
       _log = logger ?? Logger('FeedConfigStore');

  static const _fileName = 'feed_config.json';
  static const _lastRefreshTimeByUrlKey = 'lastRefreshTimeByUrl';
  static const _globalLastRefreshEpochKey = '_globalLastRefreshEpoch';
  static const _cacheDurationSecondsKey = 'cacheDurationSeconds';
  static const _lastFeedUpdatedAtKey = 'lastFeedUpdatedAt';
  static const _bareItemsLoadedAtKey = 'bareItemsLoadedAt';
  static const _tokensEnrichedAtKey = 'tokensEnrichedAt';
  static const _addressIndexingStateByAddressKey =
      'addressIndexingStateByAddress';

  static const _defaultCacheDurationSeconds = 86400; // 1 day
  static final _defaultLastFeedUpdatedAt = DateTime(2023);

  final Future<Directory> Function() _documentsDirFactory;
  final Logger _log;
  final Lock _lock = Lock();

  String _normalizeAddressKey(String address) => address.trim().toUpperCase();

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
        if (!await file.exists()) {
          return <String, dynamic>{};
        }
        final raw = await file.readAsString();
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
      try {
        final file = await resolveFile();
        await file.writeAsString(jsonEncode(config));
      } on Exception catch (e, stack) {
        _log.warning(
          'Failed to write $_fileName.',
          e,
          stack,
        );
      }
    });
  }

  /// Gets the last refresh time for a specific baseUrl.
  ///
  /// If [setLastTimeRefreshFeeds] was used (global epoch), that value is
  /// returned for any baseUrl. Otherwise returns per-url value or 1970.
  Future<DateTime> getLastRefreshTime(String baseUrl) async {
    final config = await _readConfig();
    final globalStr = config[_globalLastRefreshEpochKey] as String?;
    if (globalStr != null) {
      try {
        return DateTime.parse(globalStr);
      } on FormatException {
        // fall through to per-url
      }
    }
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

  /// Sets a global last-refresh epoch so all baseUrls are considered stale.
  /// Matches old repo's ConfigurationService.setLastTimeRefreshFeeds(DateTime(1970)).
  Future<void> setLastTimeRefreshFeeds(DateTime time) async {
    final config = await _readConfig();
    config[_globalLastRefreshEpochKey] = time.toIso8601String();
    await _writeConfig(config);
  }

  /// Sets the last refresh time for a specific baseUrl.
  /// Clears global epoch so per-url values are used again.
  Future<void> setLastRefreshTime(String baseUrl, DateTime time) async {
    final config = await _readConfig();
    config.remove(_globalLastRefreshEpochKey);
    final map =
        config[_lastRefreshTimeByUrlKey] as Map<String, dynamic>? ??
        <String, dynamic>{};
    map[baseUrl] = time.toIso8601String();
    config[_lastRefreshTimeByUrlKey] = map;
    await _writeConfig(config);
  }

  /// Deletes the last refresh time for a specific baseUrl.
  /// Matches old repo's ConfigurationService.deleteDp1LastTimeRefreshFeedByUrl.
  Future<void> deleteLastRefreshTime(String baseUrl) async {
    final config = await _readConfig();
    final map =
        config[_lastRefreshTimeByUrlKey] as Map<String, dynamic>? ??
        <String, dynamic>{};
    map.remove(baseUrl);
    config[_lastRefreshTimeByUrlKey] = map;
    await _writeConfig(config);
  }

  /// Gets the cache duration (TTL).
  ///
  /// Defaults to 1 day (86400 seconds).
  Future<Duration> getCacheDuration() async {
    final config = await _readConfig();
    final seconds =
        config[_cacheDurationSecondsKey] as int? ??
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

  /// Returns whether bare items have been fully loaded from feeds.
  Future<bool> isBareItemsLoaded() async {
    final config = await _readConfig();
    final timeStr = config[_bareItemsLoadedAtKey] as String?;
    if (timeStr == null || timeStr.isEmpty) {
      return false;
    }
    try {
      DateTime.parse(timeStr);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Returns whether token enrichment has completed for all feed bare items.
  Future<bool> isTokensEnriched() async {
    final config = await _readConfig();
    final timeStr = config[_tokensEnrichedAtKey] as String?;
    if (timeStr == null || timeStr.isEmpty) {
      return false;
    }
    try {
      DateTime.parse(timeStr);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Marks bare feed item loading as complete.
  Future<void> markBareItemsLoaded({DateTime? at}) async {
    final config = await _readConfig();
    config[_bareItemsLoadedAtKey] = (at ?? DateTime.now()).toIso8601String();
    await _writeConfig(config);
  }

  /// Marks token enrichment as complete.
  Future<void> markTokensEnriched({DateTime? at}) async {
    final config = await _readConfig();
    config[_tokensEnrichedAtKey] = (at ?? DateTime.now()).toIso8601String();
    await _writeConfig(config);
  }

  /// Clears staged feed sync markers.
  Future<void> clearSyncStages() async {
    final config = await _readConfig();
    config.remove(_bareItemsLoadedAtKey);
    config.remove(_tokensEnrichedAtKey);
    await _writeConfig(config);
  }

  /// Gets persisted indexing status for [address], if any.
  Future<AddressIndexingProcessStatus?> getAddressIndexingStatus(
    String address,
  ) async {
    final config = await _readConfig();
    final states =
        config[_addressIndexingStateByAddressKey] as Map<String, dynamic>?;
    final raw = states?[_normalizeAddressKey(address)];
    if (raw is! Map<String, dynamic>) {
      return null;
    }
    return AddressIndexingProcessStatus.fromJson(raw);
  }

  /// Gets all persisted indexing statuses keyed by normalized address.
  Future<Map<String, AddressIndexingProcessStatus>>
  getAllAddressIndexingStatuses() async {
    final config = await _readConfig();
    final states =
        config[_addressIndexingStateByAddressKey] as Map<String, dynamic>?;
    if (states == null) {
      return <String, AddressIndexingProcessStatus>{};
    }

    final result = <String, AddressIndexingProcessStatus>{};
    for (final entry in states.entries) {
      final raw = entry.value;
      if (raw is Map<String, dynamic>) {
        result[entry.key.toUpperCase()] = AddressIndexingProcessStatus.fromJson(
          raw,
        );
      }
    }
    return result;
  }

  /// Persists indexing status for [address].
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {
    final config = await _readConfig();
    final states =
        config[_addressIndexingStateByAddressKey] as Map<String, dynamic>? ??
        <String, dynamic>{};
    states[_normalizeAddressKey(address)] = status.toJson();
    config[_addressIndexingStateByAddressKey] = states;
    await _writeConfig(config);
  }

  /// Removes persisted indexing status for [address].
  Future<void> clearAddressIndexingStatus(String address) async {
    final config = await _readConfig();
    final states =
        config[_addressIndexingStateByAddressKey] as Map<String, dynamic>?;
    if (states == null) {
      return;
    }
    states.remove(_normalizeAddressKey(address));
    config[_addressIndexingStateByAddressKey] = states;
    await _writeConfig(config);
  }
}

/// Runtime/persisted state for per-address indexing process.
enum AddressIndexingProcessState {
  idle,
  indexingTriggered,
  waitingForIndexStatus,
  syncingTokens,
  paused,
  stopped,
  completed,
  failed,
}

/// Persistable status for per-address indexing process.
class AddressIndexingProcessStatus {
  const AddressIndexingProcessStatus({
    required this.state,
    required this.updatedAt,
    this.errorMessage,
  });

  factory AddressIndexingProcessStatus.fromJson(Map<String, dynamic> json) {
    final rawState = json['state']?.toString() ?? '';
    final state = AddressIndexingProcessState.values.firstWhere(
      (e) => e.name == rawState,
      orElse: () => AddressIndexingProcessState.idle,
    );
    final updatedAtRaw = json['updatedAt']?.toString();
    final updatedAt =
        DateTime.tryParse(updatedAtRaw ?? '')?.toUtc() ??
        DateTime.now().toUtc();
    final errorMessage = json['errorMessage']?.toString();
    return AddressIndexingProcessStatus(
      state: state,
      updatedAt: updatedAt,
      errorMessage: errorMessage?.isEmpty ?? true ? null : errorMessage,
    );
  }

  final AddressIndexingProcessState state;
  final DateTime updatedAt;
  final String? errorMessage;

  AddressIndexingProcessStatus copyWith({
    AddressIndexingProcessState? state,
    DateTime? updatedAt,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddressIndexingProcessStatus(
      state: state ?? this.state,
      updatedAt: updatedAt ?? this.updatedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'state': state.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (errorMessage != null && errorMessage!.isNotEmpty)
      'errorMessage': errorMessage,
  };
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
