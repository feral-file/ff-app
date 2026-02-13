import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/playlist_item.dart';

abstract class NowDisplayingObjectBase {
  NowDisplayingObjectBase({required this.connectedDevice});

  final FF1Device connectedDevice;
}

class DP1NowDisplayingObject extends NowDisplayingObjectBase {
  DP1NowDisplayingObject({
    required super.connectedDevice,
    required this.index,
    required this.items,
    required this.isSleeping,
  });

  final int index;
  final List<PlaylistItem> items;
  final bool isSleeping;

  PlaylistItem get currentItem => items[index];
}
