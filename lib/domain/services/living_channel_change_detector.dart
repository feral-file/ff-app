import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:meta/meta.dart';

/// One user-visible change on a followed living channel.
@immutable
class LivingChannelChange {
  /// Creates a change record.
  const LivingChannelChange({
    required this.type,
    required this.channelId,
    required this.channelName,
    this.playlistId,
    this.playlistName,
    this.workTitle,
  });

  /// Kind of change.
  final LivingChannelChangeType type;

  /// Affected channel id.
  final String channelId;

  /// Channel title for messages.
  final String channelName;

  /// Playlist id when applicable.
  final String? playlistId;

  /// Playlist title when applicable.
  final String? playlistName;

  /// Single work title for [LivingChannelChangeType.newWorkAdded].
  final String? workTitle;
}

/// Change categories for copy/toast.
enum LivingChannelChangeType {
  /// New playlist row on the channel.
  newPlaylistAdded,

  /// New item(s) in an existing playlist (we may emit one per item or batch).
  newWorkAdded,

  /// Playlist-level note text changed.
  playlistNoteUpdated,
}

/// Item ids + note for diffing (playlist metadata comes from [Playlist]).
@immutable
class PlaylistPollSnapshot {
  /// Creates a snapshot for one playlist.
  const PlaylistPollSnapshot({
    required this.playlist,
    required this.orderedItemIds,
    this.itemTitleById = const {},
  });

  /// Playlist row (title, note text, etag, etc.).
  final Playlist playlist;

  /// Item ids in display order.
  final List<String> orderedItemIds;

  /// Optional display titles for items (keys = item ids).
  final Map<String, String?> itemTitleById;
}

/// Pure comparison: old DB snapshot vs new DB snapshot after remote ingest.
class LivingChannelChangeDetector {
  /// Compares playlist membership and content.
  static List<LivingChannelChange> detect({
    required Channel oldChannel,
    required Channel newChannel,
    required Map<String, PlaylistPollSnapshot> oldByPlaylistId,
    required Map<String, PlaylistPollSnapshot> newByPlaylistId,
  }) {
    final out = <LivingChannelChange>[];
    final oldIds = oldByPlaylistId.keys.toSet();
    final newIds = newByPlaylistId.keys.toSet();

    for (final id in newIds.difference(oldIds)) {
      final pl = newByPlaylistId[id]!;
      out.add(
        LivingChannelChange(
          type: LivingChannelChangeType.newPlaylistAdded,
          channelId: newChannel.id,
          channelName: newChannel.name,
          playlistId: pl.playlist.id,
          playlistName: pl.playlist.name,
        ),
      );
    }

    for (final id in oldIds.intersection(newIds)) {
      final oldS = oldByPlaylistId[id]!;
      final newS = newByPlaylistId[id]!;
      final oldItemSet = oldS.orderedItemIds.toSet();
      final addedIds = newS.orderedItemIds
          .where((e) => !oldItemSet.contains(e))
          .toList();

      for (final itemId in addedIds) {
        final title = newS.itemTitleById[itemId];
        out.add(
          LivingChannelChange(
            type: LivingChannelChangeType.newWorkAdded,
            channelId: newChannel.id,
            channelName: newChannel.name,
            playlistId: newS.playlist.id,
            playlistName: newS.playlist.name,
            workTitle: title ?? itemId,
          ),
        );
      }

      final oldNote = oldS.playlist.playlistNoteText;
      final newNote = newS.playlist.playlistNoteText;
      if (oldNote != newNote && addedIds.isEmpty) {
        out.add(
          LivingChannelChange(
            type: LivingChannelChangeType.playlistNoteUpdated,
            channelId: newChannel.id,
            channelName: newChannel.name,
            playlistId: newS.playlist.id,
            playlistName: newS.playlist.name,
          ),
        );
      }
    }

    return out;
  }
}
