import 'package:app/app/providers/publisher_section_providers.dart';
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

  group('orderedPublisherIdsFromChannels', () {
    test('preserves first-seen publisher order', () {
      final result = orderedPublisherIdsFromChannels({
        'ch_a': channelA,
        'ch_b': channelB,
        'ch_c': channelC,
      });

      expect(result, [1, 2]);
    });

    test('skips channels without publishers', () {
      final result = orderedPublisherIdsFromChannels({
        'ch_orphan': channelOrphan,
      });

      expect(result, isEmpty);
    });
  });

  group('channelsForPublisherFromChannels', () {
    test('filters channels for a publisher and preserves order', () {
      final result = channelsForPublisherFromChannels({
        'ch_a': channelA,
        'ch_b': channelB,
        'ch_c': channelC,
        'ch_orphan': channelOrphan,
      }, 1);

      expect(result, [channelA, channelC]);
    });

    test('returns empty when no channels match', () {
      final result = channelsForPublisherFromChannels({
        'ch_a': channelA,
        'ch_b': channelB,
      }, 99);

      expect(result, isEmpty);
    });
  });
}
