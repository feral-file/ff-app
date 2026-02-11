import 'dart:convert';

import 'package:app/infra/config/remote_app_config.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/objectbox.g.dart' show RemoteAppConfigEntity_;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:objectbox/objectbox.dart';

class CachedRemoteConfig {
  const CachedRemoteConfig({
    required this.config,
    required this.etag,
  });

  final RemoteAppConfig config;
  final String etag;
}

/// Local-first remote config service with ETag-based refresh.
class RemoteConfigService {
  RemoteConfigService({
    required Box<RemoteAppConfigEntity> box,
    required Uri? remoteConfigUri,
    http.Client? httpClient,
    Logger? logger,
  }) : _box = box,
       _remoteConfigUri = _normalizeRemoteConfigUri(remoteConfigUri),
       _httpClient = httpClient ?? http.Client(),
       _log = logger ?? Logger('RemoteConfigService');

  final Box<RemoteAppConfigEntity> _box;
  final Uri? _remoteConfigUri;
  final http.Client _httpClient;
  final Logger _log;

  static Uri? _normalizeRemoteConfigUri(Uri? uri) {
    if (uri == null) return null;

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      return uri.replace(path: '/ff-app.json');
    }

    final last = segments.last.toLowerCase();
    if (last == 'ff-app.json') {
      return uri.replace(path: '/${segments.join('/')}');
    }
    if (last == 'app.json') {
      segments.removeLast();
      segments.add('ff-app.json');
      return uri.replace(path: '/${segments.join('/')}');
    }

    return uri.replace(path: '/${segments.join('/')}/ff-app.json');
  }

  CachedRemoteConfig? loadCached() {
    final entity = _getEntity();
    if (entity == null) return null;

    try {
      final config = RemoteAppConfig(
        publishers: _decodePublishers(entity.curatedChannelUrlsJson),
      );

      return CachedRemoteConfig(
        config: config,
        etag: entity.etag,
      );
    } on FormatException catch (e, stack) {
      _log.info(
        'Ignoring invalid cached remote config; refetching from network.',
      );
      _box.remove(entity.id);
      return null;
    } on Object catch (e, stack) {
      _log.info(
        'Failed to decode cached remote config; refetching from network.',
      );
      _box.remove(entity.id);
      return null;
    }
  }

  Future<CachedRemoteConfig> fetchAndPersist() async {
    final remoteUri = _remoteConfigUri;
    if (remoteUri == null) {
      throw const FormatException('REMOTE_CONFIG_URL is not configured.');
    }

    final response = await _httpClient.get(remoteUri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed to fetch remote config: HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Remote config payload must be a JSON object.',
      );
    }

    final parsed = RemoteAppConfig.fromJson(decoded);
    final etag = _sanitizeEtag(response.headers['etag'] ?? '');
    _putEntity(config: parsed, etag: etag);

    return CachedRemoteConfig(config: parsed, etag: etag);
  }

  /// Uses HEAD ETag comparison first and only GETs when changed.
  Future<CachedRemoteConfig?> refreshIfChanged() async {
    final remoteUri = _remoteConfigUri;
    if (remoteUri == null) return null;

    final localEtag = loadCached()?.etag ?? '';
    final headResponse = await _httpClient.head(remoteUri);
    if (headResponse.statusCode < 200 || headResponse.statusCode >= 300) {
      _log.warning(
        'HEAD remote config failed with HTTP ${headResponse.statusCode}; '
        'skipping refresh.',
      );
      return null;
    }

    final remoteEtag = _sanitizeEtag(headResponse.headers['etag'] ?? '');
    if (remoteEtag.isNotEmpty && remoteEtag == localEtag) {
      _log.fine('Remote config ETag unchanged; skipping GET.');
      return null;
    }

    return fetchAndPersist();
  }

  RemoteAppConfigEntity? _getEntity() {
    final query = _box
        .query(RemoteAppConfigEntity_.scope.equals('app'))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }

  void _putEntity({
    required RemoteAppConfig config,
    required String etag,
  }) {
    final existing = _getEntity();
    final entity = RemoteAppConfigEntity(
      scope: 'app',
      etag: etag,
      curatedChannelUrlsJson: jsonEncode(
        config.publishers.map((publisher) => publisher.toJson()).toList(),
      ),
      feedCacheDurationSec: config.feedCacheDuration.inSeconds,
      feedLastUpdatedAtUs: config.feedLastUpdatedAt
          .toUtc()
          .microsecondsSinceEpoch,
      updatedAtUs: DateTime.now().microsecondsSinceEpoch,
    )..id = existing?.id ?? 0;
    _box.put(entity);
  }

  List<RemoteConfigPublisher> _decodePublishers(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Invalid cached publishers list.');
    }

    final publishers = <RemoteConfigPublisher>[];
    for (final entry in decoded.asMap().entries) {
      final rawPublisher = entry.value;
      if (rawPublisher is! Map) {
        continue;
      }
      try {
        publishers.add(
          RemoteConfigPublisher.fromJson(
            rawPublisher.cast<String, dynamic>(),
            id: entry.key,
          ),
        );
      } on FormatException {
        continue;
      } on Object {
        continue;
      }
    }

    if (publishers.isEmpty) {
      throw const FormatException('Invalid cached publishers list.');
    }
    return publishers;
  }

  String _sanitizeEtag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll('"', '');
  }
}
