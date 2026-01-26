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
  static String get dp1FeedUrl =>
      dotenv.get('DP1_FEED_URL', fallback: '');

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
  static String get assetUrl =>
      dotenv.get('ASSET_URL', fallback: '');

  /// Check if configuration is valid (all required keys present).
  static bool get isValid =>
      dp1FeedUrl.isNotEmpty &&
      indexerApiUrl.isNotEmpty &&
      dp1FeedApiKey.isNotEmpty &&
      indexerApiKey.isNotEmpty;
}
