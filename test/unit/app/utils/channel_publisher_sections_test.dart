import 'package:app/app/utils/channel_publisher_sections.dart';
import 'package:app/domain/models/channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channelA = Channel(
    id: 'ch_a',
    name: 'Channel A',
    type: ChannelType.dp1,
    publisherId: 1,
  );
  const channelB = Channel(
    id: 'ch_b',
    name: 'Channel B',
    type: ChannelType.dp1,
    publisherId: 2,
  );
  const channelC = Channel(
    id: 'ch_c',
    name: 'Channel C',
    type: ChannelType.dp1,
    publisherId: 1,
  );
  const channelOrphan = Channel(
    id: 'ch_orphan',
    name: 'Channel Orphan',
    type: ChannelType.dp1,
  );

  group('groupChannelsByPublisherSections', () {
    test('groups by publisher and preserves first-seen section order', () {
      final sections = groupChannelsByPublisherSections(
        channels: const [channelA, channelB, channelC],
        publisherIdToName: const {1: 'Publisher One', 2: 'Publisher Two'},
      );

      expect(sections.length, 2);
      expect(sections[0].title, 'Publisher One');
      expect(sections[0].channels, const [channelA, channelC]);
      expect(sections[1].title, 'Publisher Two');
      expect(sections[1].channels, const [channelB]);
    });

    test('uses a stable fallback title when publisher name is missing', () {
      final sections = groupChannelsByPublisherSections(
        channels: const [channelA],
        publisherIdToName: const {},
      );

      expect(sections.length, 1);
      expect(sections.single.title, 'Publisher 1');
      expect(sections.single.channels, const [channelA]);
    });

    test('groups orphan channels together', () {
      final sections = groupChannelsByPublisherSections(
        channels: const [channelOrphan],
        publisherIdToName: const {},
      );

      expect(sections.length, 1);
      expect(sections.single.title, 'Other');
      expect(sections.single.channels, const [channelOrphan]);
    });

    test('empty input returns no sections', () {
      final sections = groupChannelsByPublisherSections(
        channels: const [],
        publisherIdToName: const {},
      );

      expect(sections, isEmpty);
    });
  });
}
