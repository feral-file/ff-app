import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';

/// Payload for the all playlists screen (title, description, icon).
/// Pass via [GoRouterState.extra] when navigating; not in query params.
class AllPlaylistsScreenPayload {
  const AllPlaylistsScreenPayload({
    this.title,
    this.description,
    this.iconAsset,
  });

  final String? title;
  final String? description;
  final String? iconAsset;
}

/// Parsed all-playlists query params (reverse of [buildAllPlaylistsQuery]).
typedef AllPlaylistsQueryParams = ({
  List<ChannelType>? channelTypes,
  List<String>? channelIds,
  List<PlaylistType>? playlistTypes,
});

/// Parses channel types from query param (comma-separated, e.g. "dp1,localVirtual").
List<ChannelType>? parseChannelTypes(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(',');
  final types = <ChannelType>[];
  for (final part in parts) {
    final parsed = ChannelType.fromString(part);
    if (parsed != null) types.add(parsed);
  }
  return types.isEmpty ? null : types;
}

/// Parses playlist types from query param (comma-separated, e.g. "dp1,favorite").
List<PlaylistType>? parsePlaylistTypes(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split(',');
  final types = <PlaylistType>[];
  for (final part in parts) {
    final parsed = PlaylistType.fromString(part);
    if (parsed != null) types.add(parsed);
  }
  return types.isEmpty ? null : types;
}

/// Parses channel IDs from query param (comma-separated).
List<String>? parseChannelIds(String? value) {
  if (value == null || value.isEmpty) return null;
  final ids = value
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return ids.isEmpty ? null : ids;
}

/// Builds query string for all playlists route.
String buildAllPlaylistsQuery({
  List<ChannelType>? channelTypes,
  List<String>? channelIds,
  List<PlaylistType>? playlistTypes,
}) {
  final params = <String, String>{};
  if (channelTypes != null && channelTypes.isNotEmpty) {
    params['channelTypes'] =
        channelTypes.map((t) => t.toQueryParamString()).join(',');
  }
  if (channelIds != null && channelIds.isNotEmpty) {
    params['channelIds'] = channelIds.join(',');
  }
  if (playlistTypes != null && playlistTypes.isNotEmpty) {
    params['playlistTypes'] =
        playlistTypes.map((t) => t.toQueryParamString()).join(',');
  }
  if (params.isEmpty) return '';
  return '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
}

/// Parses query params produced by [buildAllPlaylistsQuery].
/// Supports both [channelIds] and legacy [channelId] (single).
AllPlaylistsQueryParams parseAllPlaylistsQuery(Map<String, String>? query) {
  if (query == null || query.isEmpty) {
    return (channelTypes: null, channelIds: null, playlistTypes: null);
  }
  final channelIds = parseChannelIds(query['channelIds']) ??
      (query['channelId'] != null ? [query['channelId']!] : null);
  return (
    channelTypes: parseChannelTypes(query['channelTypes']),
    channelIds: channelIds,
    playlistTypes: parsePlaylistTypes(query['playlistTypes']),
  );
}

/// Parses all-playlists query from a query string (e.g. "?channelTypes=dp1").
AllPlaylistsQueryParams parseAllPlaylistsQueryFromString(String? queryString) {
  if (queryString == null || queryString.isEmpty) {
    return (channelTypes: null, channelIds: null, playlistTypes: null);
  }
  final s = queryString.startsWith('?') ? queryString : '?$queryString';
  final uri = Uri.parse('http://x/$s');
  return parseAllPlaylistsQuery(uri.queryParameters);
}
