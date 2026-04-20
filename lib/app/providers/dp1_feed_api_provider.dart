import 'package:app/infra/api/dp1_feed_api.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared DP-1 Feed HTTP client for read-heavy paths (living channel polling).
final dp1FeedApiProvider = Provider<DP1FeedApi>((ref) {
  final raw = AppConfig.dp1FeedUrl.trim();
  final base = raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  return Dp1FeedApiImpl(
    dio: dio,
    baseUrl: base.isEmpty ? 'http://invalid.local' : base,
    apiKey: AppConfig.dp1FeedApiKey,
  );
});
