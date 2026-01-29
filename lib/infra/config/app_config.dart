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

  /// Asset URL prefix for media files.
  static String get assetUrl => dotenv.get('ASSET_URL', fallback: '');

  /// FF1 Relayer server URL (WebSocket endpoint for device communication).
  /// Reads from FF1_RELAYER_URL for backward compatibility with old app.
  static String get ff1RelayerUrl => dotenv.get(
    'FF1_RELAYER_URL',
    fallback: dotenv.get(
      'FF1_RELAYER_URL',
      fallback: 'wss://relayer.feralfile.com',
    ),
  );

  /// FF1 Relayer API Key for authentication.
  /// Reads from FF1_RELAYER_API_KEY for backward compatibility with old app.
  static String get ff1RelayerApiKey => dotenv.get(
    'FF1_RELAYER_API_KEY',
    fallback: dotenv.get('FF1_RELAYER_API_KEY', fallback: ''),
  );

  /// Check if configuration is valid (all required keys present).
  static bool get isValid =>
      dp1FeedUrl.isNotEmpty &&
      indexerApiUrl.isNotEmpty &&
      dp1FeedApiKey.isNotEmpty &&
      indexerApiKey.isNotEmpty &&
      ff1RelayerUrl.isNotEmpty &&
      ff1RelayerApiKey.isNotEmpty;
}
