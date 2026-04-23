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
/// Once both `publisherAsync` and `channelAsync` have cached data (first
/// load, `hasValue` true), the UI stays grouped even if the streams reload or
/// refresh (subsequent `isLoading`). This prevents layout flicker during
/// dependency invalidation. During seed bootstrap, the channel map stream may
/// not emit until the seed DB is ready, so `channelAsync` stays loading—not a
/// completed empty map.
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

  // Both `hasValue` flags must be true. The channel map does not emit before
  // the seed DB is ready, so `lookupsReady` stays false during that phase.
  // After first load, we do not use `isLoading` to block grouping: reload does
  // not drop sections.
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
