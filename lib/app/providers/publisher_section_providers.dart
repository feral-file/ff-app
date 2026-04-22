import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Publisher id → display title for section headers.
///
/// Auto-dispose so DB watch is not kept alive after leaving browse screens.
final StreamProvider<Map<int, String>> publisherTitlesMapProvider =
    StreamProvider.autoDispose<Map<int, String>>((ref) {
  if (!ref.watch(isSeedDatabaseReadyProvider)) {
    return Stream.value(const {});
  }
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.watchPublisherTitles();
});

/// All channels keyed by id (for resolving publisher-based sections).
///
/// Auto-dispose so DB watch is not kept alive after leaving browse screens.
final StreamProvider<Map<String, Channel>> allChannelsByIdMapProvider =
    StreamProvider.autoDispose<Map<String, Channel>>((ref) {
  if (!ref.watch(isSeedDatabaseReadyProvider)) {
    return Stream.value(const {});
  }
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.watchAllChannels().map(
        (list) => {for (final c in list) c.id: c},
      );
});

/// Returns the stable publisher order from a channel map.
List<int> orderedPublisherIdsFromChannels(Map<String, Channel> channels) {
  final orderedPublisherIds = <int>[];
  final seen = <int>{};

  for (final channel in channels.values) {
    final publisherId = channel.publisherId;
    if (publisherId == null || !seen.add(publisherId)) continue;
    orderedPublisherIds.add(publisherId);
  }

  return orderedPublisherIds;
}

/// Returns the channels for one publisher, preserving source order.
List<Channel> channelsForPublisherFromChannels(
  Map<String, Channel> channels,
  int publisherId,
) {
  return [
    for (final channel in channels.values)
      if (channel.publisherId == publisherId) channel,
  ];
}

/// Publisher IDs in first-seen order from the loaded channel list.
///
/// This is the stable section order used by All Channels. It is derived from
/// [allChannelsByIdMapProvider] so the UI does not need to own grouping policy.
final allChannelsPublisherIdsProvider = Provider.autoDispose<List<int>>((ref) {
  final channels = ref.watch(allChannelsByIdMapProvider).maybeWhen(
        data: (value) => value,
        orElse: () => const <String, Channel>{},
      );
  return orderedPublisherIdsFromChannels(channels);
});

/// Channels belonging to one publisher, preserving the source channel order.
///
/// The screen can `watch` one provider per section and render each bucket
/// independently, while this provider keeps the grouping logic centralized.
final channelsByPublisherProvider =
    Provider.family.autoDispose<List<Channel>, int>((ref, publisherId) {
  final channels = ref.watch(allChannelsByIdMapProvider).maybeWhen(
        data: (value) => value,
        orElse: () => const <String, Channel>{},
      );
  return channelsForPublisherFromChannels(channels, publisherId);
});
