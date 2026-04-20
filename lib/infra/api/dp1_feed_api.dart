import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_conditional_get.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:dio/dio.dart';

/// DP1 feed API surface (matches old repo's DP1FeedApi).
///
/// All methods use domain DP1 types. Implementations perform HTTP via Dio
/// to the feed server base URL with optional Bearer auth for POST/PUT.
abstract class DP1FeedApi {
  /// Fetches a single playlist by id, or null if missing.
  Future<DP1Playlist?> getPlaylistById(String playlistId);

  /// Lists playlists with optional pagination and channel filter.
  Future<DP1PlaylistResponse> getPlaylists({
    String? cursor,
    int? limit,
    String? channelId,
  });

  /// Lists playlist items with optional pagination and channel filter.
  Future<DP1PlaylistItemsResponse> getPlaylistItems({
    String? cursor,
    int? limit,
    String? channelId,
  });

  /// Deletes a playlist on the feed (authenticated).
  Future<void> deletePlaylist(String playlistId);

  /// Lists channels with optional pagination.
  Future<DP1ChannelsResponse> getAllChannels({
    String? cursor,
    int? limit,
  });

  /// Fetches a single channel document by id.
  Future<DP1Channel> getChannelById(String channelId);

  /// Conditional GET for a single channel (ETag / If-None-Match).
  Future<ConditionalChannelGet> getChannelByIdConditional(
    String channelId, {
    String? ifNoneMatch,
  });

  /// Conditional GET for a single playlist (ETag / If-None-Match).
  Future<ConditionalPlaylistGet> getPlaylistByIdConditional(
    String playlistId, {
    String? ifNoneMatch,
  });
}

/// Implementation of [DP1FeedApi] using Dio.
///
/// Uses [baseUrl] as origin; adds Bearer [apiKey] only for POST/PUT.
class Dp1FeedApiImpl implements DP1FeedApi {
  /// Creates a feed client with shared [dio], [baseUrl], and mutating [apiKey].
  Dp1FeedApiImpl({
    required this.dio,
    required this.baseUrl,
    required this.apiKey,
  });

  /// Shared HTTP client (timeouts, interceptors owned by caller).
  final Dio dio;

  /// Feed origin, e.g. `https://feed.example` without trailing slash.
  final String baseUrl;

  /// Bearer token for authenticated writes.
  final String apiKey;

  Map<String, String> _headers(
    String method, {
    String? ifNoneMatch,
  }) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final upper = method.toUpperCase();
    if (upper == 'POST' || upper == 'PUT') {
      headers['Authorization'] = 'Bearer $apiKey';
    }
    if (ifNoneMatch != null && ifNoneMatch.isNotEmpty) {
      headers['If-None-Match'] = ifNoneMatch;
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

  String? _readEtag(Response<dynamic> response) {
    final raw = response.headers.value('etag') ??
        response.headers.value('ETag');
    return raw?.trim();
  }

  @override
  Future<ConditionalChannelGet> getChannelByIdConditional(
    String channelId, {
    String? ifNoneMatch,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/channels/$channelId');
    final response = await dio.getUri<Map<String, dynamic>>(
      uri,
      options: Options(
        headers: _headers('GET', ifNoneMatch: ifNoneMatch),
        validateStatus: (code) =>
            code != null && (code == 304 || code == 200 || code == 404),
      ),
    );
    final etag = _readEtag(response);
    final code = response.statusCode ?? 0;
    if (code == 304) {
      return ConditionalChannelGet(notModified: true, etag: etag);
    }
    if (code == 404) {
      throw Exception('Channel not found: $channelId');
    }
    if (code != 200) {
      throw Exception(
        'Failed to fetch channel $channelId: $code',
      );
    }
    final data = response.data;
    if (data == null) {
      throw Exception('Empty channel response');
    }
    return ConditionalChannelGet(
      notModified: false,
      channel: DP1Channel.fromJson(data),
      etag: etag,
    );
  }

  @override
  Future<ConditionalPlaylistGet> getPlaylistByIdConditional(
    String playlistId, {
    String? ifNoneMatch,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/playlists/$playlistId');
    final response = await dio.getUri<Map<String, dynamic>>(
      uri,
      options: Options(
        headers: _headers('GET', ifNoneMatch: ifNoneMatch),
        validateStatus: (code) =>
            code != null && (code == 304 || code == 200 || code == 404),
      ),
    );
    final etag = _readEtag(response);
    final code = response.statusCode ?? 0;
    if (code == 304) {
      return ConditionalPlaylistGet(notModified: true, etag: etag);
    }
    if (code == 404) {
      throw Exception('Playlist not found: $playlistId');
    }
    if (code != 200) {
      throw Exception(
        'Failed to fetch playlist $playlistId: $code',
      );
    }
    final data = response.data;
    if (data == null) {
      throw Exception('Empty playlist response');
    }
    return ConditionalPlaylistGet(
      notModified: false,
      playlist: DP1PlaylistResponse.fromJson(
        <String, dynamic>{
          'items': [data],
          'hasMore': false,
          'cursor': null,
        },
      ).items.single,
      etag: etag,
    );
  }
}
