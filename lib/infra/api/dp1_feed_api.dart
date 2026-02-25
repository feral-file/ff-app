import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:dio/dio.dart';

/// DP1 feed API surface (matches old repo's DP1FeedApi).
///
/// All methods use domain DP1 types. Implementations perform HTTP via Dio
/// to the feed server base URL with optional Bearer auth for POST/PUT.
abstract class DP1FeedApi {
  Future<DP1Playlist?> getPlaylistById(String playlistId);

  Future<DP1PlaylistResponse> getPlaylists({
    String? cursor,
    int? limit,
    String? channelId,
  });

  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    String? cursor,
    int? limit,
    String? channelId,
  });

  Future<void> deletePlaylist(String playlistId);

  Future<DP1ChannelsResponse> getAllChannels({
    String? cursor,
    int? limit,
  });

  Future<DP1Channel> getChannelById(String channelId);
}

/// Implementation of [DP1FeedApi] using Dio.
///
/// Uses [baseUrl] as origin; adds Bearer [apiKey] only for POST/PUT.
class Dp1FeedApiImpl implements DP1FeedApi {
  Dp1FeedApiImpl({
    required this.dio,
    required this.baseUrl,
    required this.apiKey,
  });

  final Dio dio;
  final String baseUrl;
  final String apiKey;

  Map<String, String> _headers(String method) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final upper = method.toUpperCase();
    if (upper == 'POST' || upper == 'PUT') {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    return headers;
  }

  @override
  Future<DP1Playlist?> getPlaylistById(String playlistId) async {
    final uri = Uri.parse('$baseUrl/api/v1/playlists/$playlistId');
    final response = await dio.getUri<Map<String, dynamic>>(
      uri,
      options: Options(headers: _headers('GET')),
    );
    if (response.statusCode != 200) return null;
    final data = response.data;
    return data == null
        ? null
        : DP1PlaylistResponse.fromJson(
            <String, dynamic>{
              'items': [data],
              'hasMore': false,
              'cursor': null,
            },
          ).items.single;
  }

  @override
  Future<DP1PlaylistResponse> getPlaylists({
    String? cursor,
    int? limit,
    String? channelId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/playlists');
    final queryParams = <String, String>{
      if (limit != null) 'limit': limit.toString(),
      'cursor': ?cursor,
      'channel': ?channelId,
    };
    final finalUri = uri.replace(queryParameters: queryParams);
    final response = await dio.getUri<Map<String, dynamic>>(
      finalUri,
      options: Options(headers: _headers('GET')),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch playlists: ${response.statusCode}');
    }
    final data = response.data;
    if (data == null) {
      throw Exception('Empty playlists response');
    }
    return DP1PlaylistResponse.fromJson(data);
  }

  @override
  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    String? cursor,
    int? limit,
    String? channelId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/playlist-items');
    final queryParams = <String, String>{
      if (limit != null) 'limit': limit.toString(),
      'cursor': ?cursor,
      'channel': ?channelId,
    };
    final finalUri = uri.replace(queryParameters: queryParams);
    final response = await dio.getUri<Map<String, dynamic>>(
      finalUri,
      options: Options(headers: _headers('GET')),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch playlist items: ${response.statusCode}',
      );
    }
    final data = response.data;
    if (data == null) {
      throw Exception('Empty playlist items response');
    }
    return DP1PlaylistItemsResponse.fromJson(data);
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    final uri = Uri.parse('$baseUrl/api/v1/playlists/$playlistId');
    await dio.deleteUri<void>(
      uri,
      options: Options(headers: _headers('DELETE')),
    );
  }

  @override
  Future<DP1ChannelsResponse> getAllChannels({
    String? cursor,
    int? limit,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/channels');
    final queryParams = <String, String>{
      if (limit != null) 'limit': limit.toString(),
      'cursor': ?cursor,
    };
    final finalUri = uri.replace(queryParameters: queryParams);
    final response = await dio.getUri<Map<String, dynamic>>(
      finalUri,
      options: Options(headers: _headers('GET')),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch channels: ${response.statusCode}');
    }
    final data = response.data;
    if (data == null) {
      throw Exception('Empty channels response');
    }
    return DP1ChannelsResponse.fromJson(data);
  }

  @override
  Future<DP1Channel> getChannelById(String channelId) async {
    final uri = Uri.parse('$baseUrl/api/v1/channels/$channelId');
    final response = await dio.getUri<Map<String, dynamic>>(
      uri,
      options: Options(headers: _headers('GET')),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch channel $channelId: ${response.statusCode}',
      );
    }
    final data = response.data;
    if (data == null) {
      throw Exception('Empty channel response');
    }
    return DP1Channel.fromJson(data);
  }
}
