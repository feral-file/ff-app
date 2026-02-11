import 'package:dio/dio.dart';

/// API for sending cast commands to FF1 via relayer (GET /api/cast?topicID=...).
/// Dio must be configured with baseUrl (e.g. relayer cast API URL).
abstract class TvCastApi {
  factory TvCastApi(Dio dio) = _TvCastApiImpl;

  Future<dynamic> request({
    required String topicId,
    required Map<String, dynamic> body,
  });
}

class _TvCastApiImpl implements TvCastApi {
  _TvCastApiImpl(this._dio);

  final Dio _dio;

  @override
  Future<dynamic> request({
    required String topicId,
    required Map<String, dynamic> body,
  }) async {
    final queryParameters = <String, dynamic>{
      'topicID': topicId,
    };
    final options = Options(
      method: 'GET',
      headers: <String, dynamic>{},
    );
    final result = await _dio.fetch<dynamic>(
      options.compose(
        _dio.options,
        '/api/cast',
        queryParameters: queryParameters,
        data: body,
      ),
    );
    return result.data;
  }
}
