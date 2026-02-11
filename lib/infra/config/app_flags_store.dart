import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

/// Key for "has seen Play to FF1" tooltip in [AppFlagsStore].
const String hasSeenPlayToFf1TooltipKey = 'has_seen_play_to_ff1_tooltip';

/// Simple key-value store for app-level flags and preferences.
///
/// Backed by a JSON file in the application documents directory.
class AppFlagsStore {
  /// Creates an [AppFlagsStore].
  AppFlagsStore({
    required Future<Directory> Function() documentsDirFactory,
    Logger? logger,
  })  : _documentsDirFactory = documentsDirFactory,
        _log = logger ?? Logger('AppFlagsStore');

  static const _fileName = 'app_flags.json';

  final Future<Directory> Function() _documentsDirFactory;
  final Logger _log;
  final Lock _lock = Lock();

  @visibleForTesting

  /// Resolves the flags file path.
  Future<File> resolveFile() async {
    final dir = await _documentsDirFactory();
    return File(p.join(dir.path, _fileName));
  }

  /// Reads the flags map from disk.
  Future<Map<String, dynamic>> _readFlags() async {
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
          'Failed to read $_fileName, returning empty flags.',
          e,
          stack,
        );
        return <String, dynamic>{};
      }
    });
  }

  /// Writes the flags map to disk.
  Future<void> _writeFlags(Map<String, dynamic> flags) async {
    return _lock.synchronized(() async {
      final file = await resolveFile();
      file.writeAsStringSync(jsonEncode(flags));
    });
  }

  /// Get a boolean flag
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final flags = await _readFlags();
    final value = flags[key];
    if (value is bool) {
      return value;
    }
    return defaultValue;
  }

  /// Set a boolean flag.
  Future<void> setBool(String key, bool value) async {
    final flags = await _readFlags();
    flags[key] = value;
    await _writeFlags(flags);
  }

  /// Get a string value
  Future<String?> getString(String key) async {
    final flags = await _readFlags();
    final value = flags[key];
    if (value is String) {
      return value;
    }
    return null;
  }

  /// Set a string value.
  Future<void> setString(String key, String value) async {
    final flags = await _readFlags();
    flags[key] = value;
    await _writeFlags(flags);
  }

  /// Get an integer value.
  Future<int?> getInt(String key) async {
    final flags = await _readFlags();
    final value = flags[key];
    if (value is int) {
      return value;
    }
    return null;
  }

  /// Set an integer value.
  Future<void> setInt(String key, int value) async {
    final flags = await _readFlags();
    flags[key] = value;
    await _writeFlags(flags);
  }
}

/// Provider for [AppFlagsStore].
///
/// Tests can override this provider with an in-memory fake or temp directory.
final appFlagsStoreProvider = Provider<AppFlagsStore>((ref) {
  return AppFlagsStore(
    documentsDirFactory: getApplicationDocumentsDirectory,
    logger: Logger('AppFlagsStore'),
  );
});
