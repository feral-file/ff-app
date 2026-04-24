import 'package:app/app/now_displaying/dp1_now_displaying_if_playing_this_work.dart';
import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const device = FF1Device(
    name: 'FF1',
    remoteId: 'r',
    deviceId: 'd',
    topicId: 'topic-1',
  );

  PlaylistItem item(String id) => PlaylistItem(
    id: id,
    kind: PlaylistItemKind.dp1Item,
    title: 'T',
  );

  test('null when status is not success', () {
    expect(
      dp1NowDisplayingIfPlayingThisWork(
        nowDisplaying: const InitialNowDisplayingStatus(),
        workId: 'w1',
      ),
      isNull,
    );
  });

  test('null when sleeping', () {
    final status = NowDisplayingSuccess(
      DP1NowDisplayingObject(
        connectedDevice: device,
        index: 0,
        items: [item('w1')],
        isSleeping: true,
      ),
    );
    expect(
      dp1NowDisplayingIfPlayingThisWork(nowDisplaying: status, workId: 'w1'),
      isNull,
    );
  });

  test('null when workId does not match', () {
    final status = NowDisplayingSuccess(
      DP1NowDisplayingObject(
        connectedDevice: device,
        index: 0,
        items: [item('w1')],
        isSleeping: false,
      ),
    );
    expect(
      dp1NowDisplayingIfPlayingThisWork(nowDisplaying: status, workId: 'w2'),
      isNull,
    );
  });

  test('returns object when this work is playing', () {
    final status = NowDisplayingSuccess(
      DP1NowDisplayingObject(
        connectedDevice: device,
        index: 1,
        items: [item('w0'), item('w1')],
        isSleeping: false,
      ),
    );
    final playing = dp1NowDisplayingIfPlayingThisWork(
      nowDisplaying: status,
      workId: 'w1',
    );
    expect(playing, isNotNull);
    expect(playing!.connectedDevice.topicId, 'topic-1');
    expect(playing.currentItem.id, 'w1');
  });
}
