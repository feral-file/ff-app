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

  /// FF1 Cast API URL (REST endpoint for sending commands).
  /// Uses FF1_RELAYER_URL as the base URL, converting scheme from ws:// to https://.
  static String get ff1CastApiUrl {
    var url = dotenv.get('FF1_RELAYER_URL', fallback: '');

    // Log warning if not configured
    if (url.isEmpty) {
      print('⚠️  WARNING: FF1_RELAYER_URL not configured in .env file');
      print('   Set FF1_RELAYER_URL=https://tv-cast-coordination.autonomy-system.workers.dev');
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

  /// Check if configuration is valid (all required keys present).
  static bool get isValid =>
      dp1FeedUrl.isNotEmpty &&
      indexerApiUrl.isNotEmpty &&
      dp1FeedApiKey.isNotEmpty &&
      indexerApiKey.isNotEmpty &&
      ff1RelayerUrl.isNotEmpty &&
      ff1RelayerApiKey.isNotEmpty;
}
