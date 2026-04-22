import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Publisher sections for the all-channels view.
///
/// This keeps the screen focused on rendering, while the grouping and section
/// metadata stay in one place.
final StreamProvider<List<PublisherData>> publishersProvider =
    StreamProvider.autoDispose<List<PublisherData>>((ref) {
      if (!ref.watch(isSeedDatabaseReadyProvider)) {
        return Stream.value(const <PublisherData>[]);
      }
      final databaseService = ref.watch(databaseServiceProvider);
      return databaseService.watchPublishers();
    });

/// Publisher id → display title for section headers.
final StreamProvider<Map<int, String>> publisherTitlesMapProvider =
    StreamProvider.autoDispose<Map<int, String>>((ref) {
      final publishersAsync = ref.watch(publishersProvider);
      return publishersAsync.when(
        data: (publishers) => Stream.value({
          for (final publisher in publishers) publisher.id: publisher.title,
        }),
        loading: () => Stream.value(const <int, String>{}),
        error: (error, stackTrace) => Stream.error(error, stackTrace),
      );
    });

/// Channels belonging to one publisher, preserving source order.
final channelsByPublisherProvider = StreamProvider.autoDispose
    .family<List<Channel>, int>((ref, publisherId) {
      if (!ref.watch(isSeedDatabaseReadyProvider)) {
        return Stream.value(const <Channel>[]);
      }
      final databaseService = ref.watch(databaseServiceProvider);
      return databaseService.watchAllChannels().map(
        (channels) => [
          for (final channel in channels)
            if (channel.publisherId == publisherId) channel,
        ],
      );
    });

/// All channels keyed by id (for resolving publisher-based sections).
///
/// Derived from publisher rows + per-publisher channel streams so the screen
/// only needs one stable map view.
final Provider<Map<String, Channel>> allChannelsByIdMapProvider =
    Provider.autoDispose<Map<String, Channel>>(
      (ref) {
        final publishers = ref.watch(publishersProvider).value ?? const [];
        final result = <String, Channel>{};

        for (final publisher in publishers) {
          final channelsAsync = ref.watch(
            channelsByPublisherProvider(publisher.id),
          );
          for (final channel in channelsAsync.value ?? const <Channel>[]) {
            result[channel.id] = channel;
          }
        }

        return result;
      },
    );
