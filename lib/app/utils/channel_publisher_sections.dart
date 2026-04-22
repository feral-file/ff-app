import 'package:app/domain/models/channel.dart';
import 'package:meta/meta.dart';

/// One publisher bucket for the all-channels list.
@immutable
class ChannelPublisherSection {
  /// Creates a [ChannelPublisherSection].
  const ChannelPublisherSection({
    required this.title,
    required this.channels,
  });

  /// Section heading shown in the browse UI.
  final String title;

  /// Channels in this section, in input order.
  final List<Channel> channels;
}

/// Groups [channels] into publisher sections while preserving input order.
///
/// The helper is intentionally pure so the browse screen can keep its UI logic
/// separate from the grouping rules. Channels are appended to the first bucket
/// for their publisher and never re-sorted inside that bucket.
List<ChannelPublisherSection> groupChannelsByPublisherSections({
  required List<Channel> channels,
  required Map<int, String> publisherIdToName,
}) {
  final sectionKeys = <String>[];
  final buckets = <String, _ChannelSectionBucket>{};

  void append(String key, String title, Channel channel) {
    var bucket = buckets[key];
    if (bucket == null) {
      bucket = _ChannelSectionBucket(title: title);
      buckets[key] = bucket;
      sectionKeys.add(key);
    }
    bucket.channels.add(channel);
  }

  for (final channel in channels) {
    final publisherId = channel.publisherId;
    if (publisherId != null) {
      append(
        'pub:$publisherId',
        publisherIdToName[publisherId] ?? 'Publisher $publisherId',
        channel,
      );
      continue;
    }

    append('orphan', 'Other', channel);
  }

  return [
    for (final key in sectionKeys)
      ChannelPublisherSection(
        title: buckets[key]!.title,
        channels: buckets[key]!.channels,
      ),
  ];
}

class _ChannelSectionBucket {
  _ChannelSectionBucket({required this.title});

  final String title;
  final List<Channel> channels = [];
}
