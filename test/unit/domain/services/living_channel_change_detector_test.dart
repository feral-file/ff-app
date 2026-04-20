import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/services/living_channel_change_detector.dart';
import 'package:flutter_test/flutter_test.dart';

Playlist _pl({
  required String id,
  required String name,
  String? note,
}) {
  return Playlist(
    id: id,
    name: name,
    type: PlaylistType.dp1,
    playlistNoteText: note,
  );
}

void main() {
  group('LivingChannelChangeDetector', () {
    final chOld = Channel(
      id: 'ch_1',
      name: 'C',
      type: ChannelType.living,
    );
    final chNew = Channel(
      id: 'ch_1',
      name: 'C',
      type: ChannelType.living,
      etag: 'e2',
    );

    test('detects new playlist added to channel', () {
      final oldMap = <String, PlaylistPollSnapshot>{
        'pl_a': PlaylistPollSnapshot(
          playlist: _pl(id: 'pl_a', name: 'A'),
          orderedItemIds: const ['w1'],
          itemTitleById: const {'w1': 'W1'},
        ),
      };
      final newMap = <String, PlaylistPollSnapshot>{
        'pl_a': PlaylistPollSnapshot(
          playlist: _pl(id: 'pl_a', name: 'A'),
          orderedItemIds: const ['w1'],
          itemTitleById: const {'w1': 'W1'},
        ),
        'pl_b': PlaylistPollSnapshot(
          playlist: _pl(id: 'pl_b', name: 'B new'),
          orderedItemIds: const [],
        ),
      };

      final changes = LivingChannelChangeDetector.detect(
        oldChannel: chOld,
        newChannel: chNew,
        oldByPlaylistId: oldMap,
        newByPlaylistId: newMap,
      );

      expect(changes, hasLength(1));
      expect(changes.single.type, LivingChannelChangeType.newPlaylistAdded);
      expect(changes.single.playlistId, 'pl_b');
      expect(changes.single.playlistName, 'B new');
      expect(changes.single.channelId, 'ch_1');
    });

    test('detects new work items in existing playlist', () {
      final oldMap = <String, PlaylistPollSnapshot>{
        'pl_a': PlaylistPollSnapshot(
          playlist: _pl(id: 'pl_a', name: 'A'),
          orderedItemIds: const ['w1'],
          itemTitleById: const {'w1': 'W1'},
        ),
      };
      final newMap = <String, PlaylistPollSnapshot>{
        'pl_a': PlaylistPollSnapshot(
          playlist: _pl(id: 'pl_a', name: 'A'),
          orderedItemIds: const ['w1', 'w2'],
          itemTitleById: const {'w1': 'W1', 'w2': 'Work Two'},
        ),
      };

      final changes = LivingChannelChangeDetector.detect(
        oldChannel: chOld,
        newChannel: chNew,
        oldByPlaylistId: oldMap,
        newByPlaylistId: newMap,
      );

      expect(changes, hasLength(1));
      expect(changes.single.type, LivingChannelChangeType.newWorkAdded);
      expect(changes.single.workTitle, 'Work Two');
      expect(changes.single.playlistId, 'pl_a');
    });

    test('detects playlist note update when no new items', () {
      final oldMap = <String, PlaylistPollSnapshot>{
        'pl_a': PlaylistPollSnapshot(
          playlist: _pl(id: 'pl_a', name: 'A', note: 'old'),
          orderedItemIds: const ['w1'],
        ),
      };
      final newMap = <String, PlaylistPollSnapshot>{
        'pl_a': PlaylistPollSnapshot(
          playlist: _pl(id: 'pl_a', name: 'A', note: 'new'),
          orderedItemIds: const ['w1'],
        ),
      };

      final changes = LivingChannelChangeDetector.detect(
        oldChannel: chOld,
        newChannel: chNew,
        oldByPlaylistId: oldMap,
        newByPlaylistId: newMap,
      );

      expect(changes, hasLength(1));
      expect(changes.single.type, LivingChannelChangeType.playlistNoteUpdated);
    });

    test('does not emit note update when new items were also added', () {
      final oldMap = <String, PlaylistPollSnapshot>{
        'pl_a': PlaylistPollSnapshot(
          playlist: _pl(id: 'pl_a', name: 'A', note: 'old'),
          orderedItemIds: const ['w1'],
        ),
      };
      final newMap = <String, PlaylistPollSnapshot>{
        'pl_a': PlaylistPollSnapshot(
          playlist: _pl(id: 'pl_a', name: 'A', note: 'new'),
          orderedItemIds: const ['w1', 'w2'],
          itemTitleById: const {'w2': 'W2'},
        ),
      };

      final changes = LivingChannelChangeDetector.detect(
        oldChannel: chOld,
        newChannel: chNew,
        oldByPlaylistId: oldMap,
        newByPlaylistId: newMap,
      );

      expect(changes, hasLength(1));
      expect(changes.single.type, LivingChannelChangeType.newWorkAdded);
    });
  });
}
