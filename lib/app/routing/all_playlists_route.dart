import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';

/// Parsed all-playlists query params (reverse of [buildAllPlaylistsQuery]).
typedef AllPlaylistsQueryParams = ({
  List<ChannelType>? channelTypes,
  List<String>? channelIds,
  List<PlaylistType>? playlistTypes,
});

/// Parses channel types from query param (e.g. "dp1,localVirtual").
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

/// Parses playlist types from query param (e.g. "dp1,favorite").
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
  final encoded =
      params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}');
  return '?${encoded.join('&')}';
}

/// Parses query params produced by [buildAllPlaylistsQuery].
/// Supports channelIds and legacy channelId (single) query keys.
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

/// Metadata for the all-playlists screen header.
typedef AllPlaylistsMetadata = ({
  String? title,
  String? description,
  String? iconAsset,
});

/// Derives header metadata from route params so the same URL renders
/// identical UI whether reached via push or direct/deep link.
/// Makes the route self-describing without ephemeral navigation extras.
AllPlaylistsMetadata deriveAllPlaylistsMetadata(
  AllPlaylistsQueryParams params,
) {
  final ids = params.channelIds;
  final types = params.channelTypes;
  final playlistTypes = params.playlistTypes;

  // Channel-scoped: single or multi-channel View all for Playlists or Address.
  if (ids != null && ids.isNotEmpty) {
    final isSingleChannel = ids.length == 1;
    final isAddressOnly = playlistTypes != null &&
        playlistTypes.length == 1 &&
        playlistTypes.contains(PlaylistType.addressBased);
    if (isAddressOnly) {
      const singleDesc =
          'Content from wallet addresses you add to this channel.';
      const multiDesc =
          'Content from wallet addresses you add to these channels.';
      return (
        title: 'Address',
        description: isSingleChannel ? singleDesc : multiDesc,
        iconAsset: 'assets/images/icon_account.svg',
      );
    }
    const playlistsSingleDesc = 'All playlists in this channel.';
    const playlistsMultiDesc = 'All playlists from the selected channels.';
    return (
      title: 'Playlists',
      description: isSingleChannel ? playlistsSingleDesc : playlistsMultiDesc,
      iconAsset: 'assets/images/list.svg',
    );
  }

  // Type-scoped: Me, Curated, or combined.
  if (types != null && types.isNotEmpty) {
    final hasDp1 = types.contains(ChannelType.dp1);
    final hasLocalVirtual = types.contains(ChannelType.localVirtual);
    if (hasLocalVirtual && !hasDp1) {
      return (
        title: 'Me',
        description:
            'Content from wallet addresses you add. Browse '
            "works you own or explore any address you're curious about.",
        iconAsset: 'assets/images/icon_account.svg',
      );
    }
    if (hasDp1 && !hasLocalVirtual) {
      return (
        title: 'Curated',
        description:
            'Playlists assembled by Feral File and invited '
            'artists and curators. Early recommendations to '
            'help you explore digital art.',
        iconAsset: 'assets/images/D.svg',
      );
    }
    if (hasDp1 && hasLocalVirtual) {
      return (
        title: 'All playlists',
        description: null,
        iconAsset: null,
      );
    }
  }

  return (title: null, description: null, iconAsset: null);
}
