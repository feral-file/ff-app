import 'dart:convert';

import 'package:app/infra/config/app_config.dart';
import 'package:http/http.dart' as http;

/// Pubdoc HTTP surface used by infra services.
///
/// This interface intentionally exposes raw strings / JSON maps so that
/// higher-level services can control parsing and domain mapping.
abstract class PubDocApi {
  /// Fetches version compatibility JSON mapping.
  ///
  /// Returns an empty map on error or when configuration is missing.
  Future<Map<String, dynamic>> getVersionCompatibility();

  /// Fetches raw versions.json content.
  ///
  /// Returns an empty string on error or when configuration is missing.
  Future<String> getVersionContent();

  /// Fetches apple_model_identifier.json content used for device mapping.
  ///
  /// Returns the raw JSON string or empty string on error.
  Future<String> getAppleModelIdentifier();
}

/// Default implementation of [PubDocApi] using [http.Client].
class PubDocApiImpl implements PubDocApi {
  /// Creates a pubDoc API client.
  ///
  /// When [baseUri] is null, [AppConfig.releaseNotesMarkdownUrl] is used
  /// as the base and resolved into concrete endpoints.
  PubDocApiImpl({
    http.Client? httpClient,
    Uri? baseUri,
  }) : _httpClient = httpClient ?? http.Client(),
       _baseUri = baseUri;

  final http.Client _httpClient;
  final Uri? _baseUri;

  Uri? get _defaultBaseUri {
    final url = AppConfig.pubdocUrl;
    if (url.isEmpty) {
      return null;
    }
    return Uri.tryParse(url);
  }

  @override
  Future<Map<String, dynamic>> getVersionCompatibility() async {
    final baseUri = _baseUri ?? _defaultBaseUri;
    if (baseUri == null) {
      return <String, dynamic>{};
    }

    final uri = _resolveAppPath(baseUri, 'version_compatibility.json');

    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{};
      }
      if (response.body.isEmpty) {
        return <String, dynamic>{};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } on Exception {
      return <String, dynamic>{};
    }
  }

  @override
  Future<String> getVersionContent() async {
    final baseUri = _baseUri ?? _defaultBaseUri;
    if (baseUri == null) {
      return '';
    }

    final uri = _resolveAppPath(baseUri, 'versions.json');

    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return '';
      }
      return response.body;
    } on Exception {
      return '';
    }
  }

  @override
  Future<String> getAppleModelIdentifier() async {
    final baseUri = _baseUri ?? _defaultBaseUri;
    if (baseUri == null) {
      return '';
    }

    final uri = _resolveAppPath(baseUri, 'apple_model_identifier.json');

    try {
      final response = await _httpClient.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return '';
      }
      return response.body;
    } on Exception {
      return '';
    }
  }

  Uri _resolveAppPath(Uri baseUri, String tailSegment) {
    final lowerPath = baseUri.path.toLowerCase();

    if (lowerPath.endsWith('/${tailSegment.toLowerCase()}')) {
      return baseUri;
    }

    final baseSegments = baseUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();

    final pathSegments = <String>[
      ...baseSegments,
      if (!lowerPath.startsWith('/app/')) 'app',
      tailSegment,
    ];

    return baseUri.replace(pathSegments: pathSegments);
  }
}
