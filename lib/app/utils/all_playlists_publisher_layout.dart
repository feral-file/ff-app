import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/utils/playlist_publisher_sections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of `resolveAllPlaylistsPublisherLayout`.
typedef AllPlaylistsPublisherLayout = ({
  bool useSectionHeaders,
  List<PlaylistPublisherSection> sections,
});

/// Resolves whether All Playlists should show publisher sections and the
/// grouped section list.
///
/// Once lookup streams have emitted at least once (first load), the UI stays
/// grouped even if the streams reload or refresh (subsequent `isLoading`).
/// This prevents layout flicker during dependency invalidation.
///
/// Callers that are already **channel-scoped** should not subscribe to lookup
/// providers and should pass [playlists] only after their own early return;
/// this function is still used in tests with channel-scoped true to assert
/// flat layout.
AllPlaylistsPublisherLayout resolveAllPlaylistsPublisherLayout({
  required bool isChannelScoped,
  required bool seedDatabaseReady,
  required AsyncValue<Map<int, String>> publisherAsync,
  required AsyncValue<Map<String, Channel>> channelAsync,
  required List<Playlist> playlists,
}) {
  if (isChannelScoped) {
    return (useSectionHeaders: false, sections: const []);
  }

  /// Both streams must have emitted at least once (have cached data) to group.
  /// `isLoading` is not checked: reload/refresh is invisible to the UI.
  final lookupsReady = publisherAsync.hasValue && channelAsync.hasValue;

  final channelMap = channelAsync.value ?? const <String, Channel>{};
  final publisherMap = publisherAsync.value ?? const <int, String>{};

  final sections = groupPlaylistsByPublisherSections(
    playlists: playlists,
    channelById: channelMap,
    publisherIdToName: publisherMap,
  );

  final use = shouldUsePublisherGroupedLayout(
    isChannelScoped: false,
    seedDatabaseReady: seedDatabaseReady,
    channelAndPublisherLookupsReady: lookupsReady,
    sectionCount: sections.length,
  );

  return (useSectionHeaders: use, sections: sections);
}
