import 'package:app/infra/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:sentry_dio/sentry_dio.dart';

/// Interceptor that adds the relayer API key to TV Cast requests.
/// Matches old repo's TVKeyInterceptor (header API-KEY).
class TvCastApiKeyInterceptor extends Interceptor {
  /// Creates an interceptor that injects the provided relayer API key.
  TvCastApiKeyInterceptor(this._apiKey);

  final String _apiKey;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (_apiKey.isNotEmpty) {
      options.headers['API-KEY'] = _apiKey;
    }
    handler.next(options);
  }
}

/// Creates a Dio instance configured for TV Cast (relayer) API.
/// Uses baseUrl, timeouts, and API-KEY header. Matches old repo's tvCast Dio.
Dio createTvCastDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.ff1CastApiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  )..addSentry();
  dio.interceptors.add(
    TvCastApiKeyInterceptor(AppConfig.ff1RelayerApiKey),
  );
  return dio;
}
