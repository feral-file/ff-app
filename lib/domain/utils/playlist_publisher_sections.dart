import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:meta/meta.dart';

/// One publisher (or channel) bucket for the all-playlists list.
@immutable
class PlaylistPublisherSection {
  /// Creates a [PlaylistPublisherSection].
  const PlaylistPublisherSection({
    required this.title,
    required this.playlists,
  });

  /// Section heading (publisher name, or channel name when no publisher).
  final String title;

  /// Playlists in this section (order preserved from the input list).
  final List<Playlist> playlists;
}

/// Groups [playlists] into sections by publisher (via [Channel.publisherId]).
///
/// Playlists without a resolvable channel use [Channel.myCollectionId] rules or
/// fall back to "Other". Section order follows [playlists] iteration (which
/// should already be publisher-ordered from the DB).
List<PlaylistPublisherSection> groupPlaylistsByPublisherSections({
  required List<Playlist> playlists,
  required Map<String, Channel> channelById,
  required Map<int, String> publisherIdToName,
}) {
  final keys = <String>[];
  final buckets = <String, _SectionBucket>{};

  void append(String key, String title, Playlist playlist) {
    var bucket = buckets[key];
    if (bucket == null) {
      bucket = _SectionBucket(title: title);
      buckets[key] = bucket;
      keys.add(key);
    }
    bucket.playlists.add(playlist);
  }

  for (final p in playlists) {
    final cid = p.channelId;
    if (cid != null && cid.isNotEmpty) {
      final ch = channelById[cid];
      if (ch != null) {
        final pubId = ch.publisherId;
        final title = pubId != null
            ? (publisherIdToName[pubId] ?? 'Publisher')
            : ch.name;
        final key = pubId != null ? 'pub:$pubId' : 'ch:$cid';
        append(key, title, p);
        continue;
      }
      if (cid == Channel.myCollectionId) {
        append('ch:${Channel.myCollectionId}', 'My Collection', p);
        continue;
      }
      append('missing:$cid', 'Other', p);
      continue;
    }
    append('orphan', 'Other', p);
  }

  return [
    for (final k in keys)
      PlaylistPublisherSection(
        title: buckets[k]!.title,
        playlists: buckets[k]!.playlists,
      ),
  ];
}

/// Whether All Playlists should show publisher section headers.
///
/// [channelAndPublisherLookupsReady] must be true before calling
/// [groupPlaylistsByPublisherSections]; otherwise missing channel rows produce
/// incorrect "Other" buckets while maps are still loading.
///
/// [seedDatabaseReady] must be true. Publisher/title lookup may still complete
/// with an empty map before the seed is fully usable; the channel id → channel
/// lookup typically **does not emit** until the seed DB is ready, so it stays
/// loading rather than a false `hasValue` with `{}`. Rely on
/// [channelAndPublisherLookupsReady] and [seedDatabaseReady] together so
/// grouping never runs on partial bootstrap data.
bool shouldUsePublisherGroupedLayout({
  required bool isChannelScoped,
  required bool seedDatabaseReady,
  required bool channelAndPublisherLookupsReady,
  required int sectionCount,
}) {
  return !isChannelScoped &&
      seedDatabaseReady &&
      channelAndPublisherLookupsReady &&
      sectionCount > 1;
}

class _SectionBucket {
  _SectionBucket({required this.title});

  final String title;
  final List<Playlist> playlists = [];
}
