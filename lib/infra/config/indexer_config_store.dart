import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars // Reason: infra persistence store; docs noise outweighs benefit for stable API.

/// Persistent store for indexer sync metadata.
///
/// This mirrors the old repo's ConfigurationService *indexer-related* surfaces:
/// - Per-address last update change anchor
/// - Per-address indexing info (workflowId)
/// - Per-address last fetch token time
///
/// File format:
/// ```json
/// {
///   "lastUpdateChangeAnchorByAddress": {"0xABC...": 42},
///   "addressIndexingInfoByAddress": {"0xABC...": {"workflow_id": "wf123"}},
///   "addressLastFetchTokenTimeByAddress": {"0xABC...": "2026-02-03T00:00:00.000Z"}
/// }
/// ```
class IndexerConfigStore {
  /// Creates an [IndexerConfigStore].
  IndexerConfigStore({
    required Future<Directory> Function() documentsDirFactory,
    Logger? logger,
  })  : _documentsDirFactory = documentsDirFactory,
        _log = logger ?? Logger('IndexerConfigStore');

  static const _fileName = 'indexer_config.json';
  static const _anchorsKey = 'lastUpdateChangeAnchorByAddress';
  static const _indexingInfoKey = 'addressIndexingInfoByAddress';
  static const _lastFetchTimeKey = 'addressLastFetchTokenTimeByAddress';

  final Future<Directory> Function() _documentsDirFactory;
  final Logger _log;
  final Lock _lock = Lock();

  @visibleForTesting
  Future<File> resolveFile() async {
    final dir = await _documentsDirFactory();
    return File(p.join(dir.path, _fileName));
  }

  String _normalizeAddressKey(String address) => address.toUpperCase();

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

  Future<void> _writeConfig(Map<String, dynamic> config) async {
    return _lock.synchronized(() async {
      final file = await resolveFile();
      file.writeAsStringSync(jsonEncode(config));
    });
  }

  /// Returns the last update change anchor for [address], if set.
  Future<int?> getAnchor(String address) async {
    final config = await _readConfig();
    final map = config[_anchorsKey] as Map<String, dynamic>?;
    final raw = map?[_normalizeAddressKey(address)];
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }

  /// Returns all anchors keyed by normalized address.
  Future<Map<String, int>> getAllAnchors() async {
    final config = await _readConfig();
    final map = config[_anchorsKey] as Map<String, dynamic>?;
    if (map == null) return <String, int>{};

    final result = <String, int>{};
    for (final entry in map.entries) {
      final v = entry.value;
      final parsed = v is int ? v : int.tryParse(v.toString());
      if (parsed != null) {
        result[entry.key.toUpperCase()] = parsed;
      }
    }
    return result;
  }

  /// Persists the last update change anchor for [address].
  Future<void> setAnchor(String address, int anchor) async {
    final config = await _readConfig();
    final map = config[_anchorsKey] as Map<String, dynamic>? ??
        <String, dynamic>{};
    map[_normalizeAddressKey(address)] = anchor;
    config[_anchorsKey] = map;
    await _writeConfig(config);
  }

  /// Removes the anchor entry for [address].
  Future<void> removeAnchor(String address) async {
    final config = await _readConfig();
    final map = config[_anchorsKey] as Map<String, dynamic>?;
    if (map == null) return;
    map.remove(_normalizeAddressKey(address));
    config[_anchorsKey] = map;
    await _writeConfig(config);
  }

  /// Returns the stored workflowId for [address], if set.
  Future<String?> getIndexingWorkflowId(String address) async {
    final config = await _readConfig();
    final map = config[_indexingInfoKey] as Map<String, dynamic>?;
    final raw = map?[_normalizeAddressKey(address)];
    if (raw is Map) {
      final workflowId = (raw['workflow_id'] ?? raw['workflowId'])?.toString();
      if (workflowId != null && workflowId.isNotEmpty) {
        return workflowId;
      }
    }
    return null;
  }

  /// Sets the stored workflowId for [address].
  Future<void> setIndexingWorkflowId({
    required String address,
    required String workflowId,
  }) async {
    final config = await _readConfig();
    final map = config[_indexingInfoKey] as Map<String, dynamic>? ??
        <String, dynamic>{};
    map[_normalizeAddressKey(address)] = <String, dynamic>{
      'workflow_id': workflowId,
    };
    config[_indexingInfoKey] = map;
    await _writeConfig(config);
  }

  /// Removes indexing info entry for [address].
  Future<void> removeIndexingInfo(String address) async {
    final config = await _readConfig();
    final map = config[_indexingInfoKey] as Map<String, dynamic>?;
    if (map == null) return;
    map.remove(_normalizeAddressKey(address));
    config[_indexingInfoKey] = map;
    await _writeConfig(config);
  }

  /// Returns the last fetch token time for [address], if set.
  Future<DateTime?> getLastFetchTokenTime(String address) async {
    final config = await _readConfig();
    final map = config[_lastFetchTimeKey] as Map<String, dynamic>?;
    final raw = map?[_normalizeAddressKey(address)];
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw.toString());
    return parsed?.toUtc();
  }

  /// Returns all last fetch token times keyed by normalized address.
  Future<Map<String, DateTime>> getAllLastFetchTokenTimes() async {
    final config = await _readConfig();
    final map = config[_lastFetchTimeKey] as Map<String, dynamic>?;
    if (map == null) return <String, DateTime>{};
    final result = <String, DateTime>{};
    for (final entry in map.entries) {
      final parsed = DateTime.tryParse(entry.value.toString());
      if (parsed != null) {
        result[entry.key.toUpperCase()] = parsed.toUtc();
      }
    }
    return result;
  }

  /// Persists last fetch token time for [address].
  Future<void> setLastFetchTokenTime(String address, DateTime time) async {
    final config = await _readConfig();
    final map = config[_lastFetchTimeKey] as Map<String, dynamic>? ??
        <String, dynamic>{};
    map[_normalizeAddressKey(address)] = time.toUtc().toIso8601String();
    config[_lastFetchTimeKey] = map;
    await _writeConfig(config);
  }

  /// Removes last fetch token time entry for [address].
  Future<void> removeLastFetchTokenTime(String address) async {
    final config = await _readConfig();
    final map = config[_lastFetchTimeKey] as Map<String, dynamic>?;
    if (map == null) return;
    map.remove(_normalizeAddressKey(address));
    config[_lastFetchTimeKey] = map;
    await _writeConfig(config);
  }
}

/// Provider for [IndexerConfigStore].
///
/// Tests should override this provider with a temp-dir backed instance.
final indexerConfigStoreProvider = Provider<IndexerConfigStore>((ref) {
  return IndexerConfigStore(
    documentsDirFactory: getApplicationDocumentsDirectory,
    logger: Logger('IndexerConfigStore'),
  );
});
