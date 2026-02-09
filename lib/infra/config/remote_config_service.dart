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
      return uri.replace(path: '/app.json');
    }

    final last = segments.last.toLowerCase();
    if (last == 'app.json') {
      return uri;
    }

    return uri.replace(path: '/${segments.join('/')}/app.json');
  }

  CachedRemoteConfig? loadCached() {
    final entity = _getEntity();
    if (entity == null) return null;

    final config = RemoteAppConfig(
      curatedChannelUrls: _decodeChannelUrls(entity.curatedChannelUrlsJson),
      feedCacheDuration: Duration(seconds: entity.feedCacheDurationSec),
      feedLastUpdatedAt: DateTime.fromMicrosecondsSinceEpoch(
        entity.feedLastUpdatedAtUs,
        isUtc: true,
      ),
    );

    return CachedRemoteConfig(
      config: config,
      etag: entity.etag,
    );
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
      curatedChannelUrlsJson: jsonEncode(config.curatedChannelUrls),
      feedCacheDurationSec: config.feedCacheDuration.inSeconds,
      feedLastUpdatedAtUs: config.feedLastUpdatedAt
          .toUtc()
          .microsecondsSinceEpoch,
      updatedAtUs: DateTime.now().microsecondsSinceEpoch,
    )..id = existing?.id ?? 0;
    _box.put(entity);
  }

  List<String> _decodeChannelUrls(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Invalid cached channel URL list.');
    }
    return decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }

  String _sanitizeEtag(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.replaceAll('"', '');
  }
}
