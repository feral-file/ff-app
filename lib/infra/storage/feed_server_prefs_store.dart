import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

/// Persistence store for DP-1 custom feed servers.
///
/// This store is intentionally implemented as a small JSON file in the app's
/// documents directory:
/// - portable and auditable
/// - no additional schema/migrations
/// - easy to inspect during development
///
/// File format:
/// `{ "customBaseUrls": ["https://example.org", "..."] }`
class FeedServerPrefsStore {
  /// Creates a [FeedServerPrefsStore].
  FeedServerPrefsStore({
    required Future<Directory> Function() documentsDirFactory,
    Logger? logger,
  }) : _documentsDirFactory = documentsDirFactory,
       _log = logger ?? Logger('FeedServerPrefsStore');

  static const _fileName = 'feed_servers.json';
  static const _customBaseUrlsKey = 'customBaseUrls';

  final Future<Directory> Function() _documentsDirFactory;
  final Logger _log;
  final Lock _lock = Lock();

  @visibleForTesting
  /// Resolves the prefs file path.
  Future<File> resolveFile() async {
    final dir = await _documentsDirFactory();
    return File(p.join(dir.path, _fileName));
  }

  /// Reads custom feed server baseUrls.
  Future<List<String>> readCustomBaseUrls() async {
    return _lock.synchronized(() async {
      try {
        final file = await resolveFile();
        if (!file.existsSync()) {
          return <String>[];
        }
        final raw = file.readAsStringSync();
        if (raw.trim().isEmpty) {
          return <String>[];
        }
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) {
          _log.warning('Invalid JSON shape in $_fileName, resetting.');
          return <String>[];
        }

        final list = decoded[_customBaseUrlsKey];
        if (list is! List) {
          return <String>[];
        }

        final urls = list
            .map((e) => e?.toString())
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        return urls;
      } on Exception catch (e, stack) {
        _log.warning(
          'Failed to read $_fileName, returning empty list.',
          e,
          stack,
        );
        return <String>[];
      }
    });
  }

  /// Writes custom feed server baseUrls.
  Future<void> writeCustomBaseUrls(List<String> baseUrls) async {
    return _lock.synchronized(() async {
      final normalized = baseUrls
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      final file = await resolveFile();
      final payload = <String, dynamic>{
        _customBaseUrlsKey: normalized,
      };
      file.writeAsStringSync(jsonEncode(payload));
    });
  }

  /// Adds a custom feed server baseUrl.
  Future<void> addCustomBaseUrl(String baseUrl) async {
    final existing = await readCustomBaseUrls();
    if (existing.contains(baseUrl)) return;
    await writeCustomBaseUrls(<String>[...existing, baseUrl]);
  }

  /// Removes a custom feed server baseUrl.
  Future<void> removeCustomBaseUrl(String baseUrl) async {
    final existing = await readCustomBaseUrls();
    final updated = existing.where((e) => e != baseUrl).toList();
    await writeCustomBaseUrls(updated);
  }
}

/// Provider for [FeedServerPrefsStore].
///
/// Tests should override this provider with an in-memory fake.
final feedServerPrefsStoreProvider = Provider<FeedServerPrefsStore>((ref) {
  return FeedServerPrefsStore(
    documentsDirFactory: getApplicationDocumentsDirectory,
    logger: Logger('FeedServerPrefsStore'),
  );
});
