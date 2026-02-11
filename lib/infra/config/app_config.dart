import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Application configuration loaded from environment variables.
/// Provides type-safe access to configuration values.
class AppConfig {
  /// Private constructor to prevent instantiation.
  AppConfig._();

  /// Initialize the configuration by loading the .env file.
  static Future<void> initialize() async {
    await dotenv.load();
  }

  /// DP1 Feed Server URL.
  static String get dp1FeedUrl => dotenv.get('DP1_FEED_URL', fallback: '');

  /// DP1 Feed API Key for authentication.
  static String get dp1FeedApiKey =>
      dotenv.get('DP1_FEED_API_KEY', fallback: '');

  /// Indexer API URL (GraphQL endpoint).
  static String get indexerApiUrl =>
      dotenv.get('INDEXER_API_URL', fallback: '');

  /// Indexer API Key for authentication.
  static String get indexerApiKey =>
      dotenv.get('INDEXER_API_KEY', fallback: '');

  /// Max concurrent enrichment workers for feed token enrichment.
  ///
  /// Defaults to 4 if unset or invalid.
  static int get indexerEnrichmentMaxThreads {
    final raw = dotenv.get('INDEXER_ENRICHMENT_MAX_THREADS', fallback: '4');
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      return 4;
    }
    return parsed;
  }

  /// Asset URL prefix for media files.
  static String get assetUrl => dotenv.get('ASSET_URL', fallback: '');

  /// FF1 Relayer server URL (WebSocket endpoint for device communication).
  /// Reads from FF1_RELAYER_URL (new naming), falls back to TV_NOTIFICATION_URL (old naming).
  /// Converts scheme to wss:// for secure WebSocket if needed.
  static String get ff1RelayerUrl {
    var url = dotenv.get(
      'FF1_RELAYER_URL',
      fallback: dotenv.get(
        'TV_NOTIFICATION_URL',
        fallback: 'wss://relayer.feralfile.com',
      ),
    );

    // Convert https:// to wss:// for WebSocket
    if (url.startsWith('https://')) {
      url = url.replaceFirst('https://', 'wss://');
    } else if (url.startsWith('http://')) {
      url = url.replaceFirst('http://', 'ws://');
    }

    return url;
  }

  /// FF1 Relayer API Key for authentication.
  /// Reads from FF1_RELAYER_API_KEY (new naming), falls back to TV_API_KEY (old naming).
  static String get ff1RelayerApiKey => dotenv.get(
    'FF1_RELAYER_API_KEY',
    fallback: dotenv.get('TV_API_KEY', fallback: ''),
  );

  /// Domain Resolver URL (Domain Resolver API endpoint
  /// for resolving Ethereum and Tezos addresses from ENS and TNS domains)
  static String get domainResolverUrl =>
      dotenv.get('DOMAIN_RESOLVER_URL', fallback: '');

  /// Domain Resolver API Key for authentication.
  static String get domainResolverApiKey =>
      dotenv.get('DOMAIN_RESOLVER_API_KEY', fallback: '');

  /// FF1 Cast API URL (REST endpoint for sending commands).
  /// Uses FF1_RELAYER_URL as the base URL, converting scheme from ws:// to https://.
  static String get ff1CastApiUrl {
    var url = dotenv.get('FF1_RELAYER_URL', fallback: '');

    // Log warning if not configured
    if (url.isEmpty) {
      print('⚠️  WARNING: FF1_RELAYER_URL not configured in .env file');
      return '';
    }

    // Convert ws:// to https:// or wss:// to https:// for REST API
    if (url.startsWith('ws://')) {
      url = url.replaceFirst('ws://', 'https://');
    } else if (url.startsWith('wss://')) {
      url = url.replaceFirst('wss://', 'https://');
    }

    return url;
  }

  /// Remote config JSON URL, expected to end with `/ff-app.json`.
  static String get remoteConfigUrl =>
      dotenv.get('REMOTE_CONFIG_URL', fallback: '');

  /// Check if configuration is valid (all required keys present).
  static bool get isValid =>
      dp1FeedUrl.isNotEmpty &&
      indexerApiUrl.isNotEmpty &&
      dp1FeedApiKey.isNotEmpty &&
      indexerApiKey.isNotEmpty &&
      remoteConfigUrl.isNotEmpty &&
      ff1RelayerUrl.isNotEmpty &&
      ff1RelayerApiKey.isNotEmpty;

  /// Get validation errors for all missing required configuration values.
  /// Returns a list of error messages for missing variables.
  static List<String> getValidationErrors() {
    final errors = <String>[];

    if (dp1FeedUrl.isEmpty) {
      errors.add('DP1_FEED_URL is missing');
    }
    if (indexerApiUrl.isEmpty) {
      errors.add('INDEXER_API_URL is missing');
    }
    if (dp1FeedApiKey.isEmpty) {
      errors.add('DP1_FEED_API_KEY is missing');
    }
    if (indexerApiKey.isEmpty) {
      errors.add('INDEXER_API_KEY is missing');
    }
    if (ff1RelayerUrl.isEmpty) {
      errors.add('FF1_RELAYER_URL (or TV_NOTIFICATION_URL) is missing');
    }
    if (ff1RelayerApiKey.isEmpty) {
      errors.add('FF1_RELAYER_API_KEY (or TV_API_KEY) is missing');
    }
    if (remoteConfigUrl.isEmpty) {
      errors.add('REMOTE_CONFIG_URL is missing');
    }

    return errors;
  }

  /// Get a formatted error message for all missing configuration values.
  static String getValidationErrorMessage() {
    final errors = getValidationErrors();
    if (errors.isEmpty) {
      return 'Configuration is valid';
    }
    return 'Missing required configuration:\n${errors.map((e) => '  • $e').join('\n')}';
  }
}
