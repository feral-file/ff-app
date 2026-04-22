import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/stream_provider.dart';

/// Publisher sections for the all-channels view.
///
/// This keeps the screen focused on rendering, while the grouping and section
/// metadata stay in one place.
final StreamProvider<List<PublisherData>> publishersProvider =
    StreamProvider.autoDispose<List<PublisherData>>((ref) {
      if (!ref.watch(isSeedDatabaseReadyProvider)) {
        // Keep the provider pending until the seed DB is ready so browse
        // screens stay in a retryable loading state instead of collapsing
        // into a false empty result during first-install bootstrap.
        return const Stream<List<PublisherData>>.empty();
      }
      final databaseService = ref.watch(databaseServiceProvider);
      return databaseService.watchPublishers();
    });

/// Publisher id → display title for section headers.
final StreamProvider<Map<int, String>> publisherTitlesMapProvider =
    StreamProvider.autoDispose<Map<int, String>>((ref) {
      final publishersAsync = ref.watch(publishersProvider);
      switch (publishersAsync) {
        case AsyncData<List<PublisherData>>(value: final publishers):
          return Stream.value({
            for (final publisher in publishers) publisher.id: publisher.title,
          });
        case AsyncError<List<PublisherData>>(:final error, :final stackTrace):
          return Stream<Map<int, String>>.error(error, stackTrace);
        case AsyncLoading<List<PublisherData>>():
          return Stream.value(const <int, String>{});
      }
    });

/// Channels belonging to one publisher, preserving source order.
///
/// [publisherId] is nullable so the curated screen can also render channels
/// without a publisher bucket.
final StreamProviderFamily<List<Channel>, int?> channelsByPublisherProvider = StreamProvider.autoDispose
    .family<List<Channel>, int?>((ref, publisherId) {
      if (!ref.watch(isSeedDatabaseReadyProvider)) {
        return const Stream<List<Channel>>.empty();
      }
      final databaseService = ref.watch(databaseServiceProvider);
      return databaseService.watchChannelsByPublisherId(
        publisherId,
        type: ChannelType.dp1,
      );
    });

/// All channels keyed by id (for resolving publisher-based sections).
///
/// Auto-dispose so DB watch is not kept alive after leaving browse screens.
final StreamProvider<Map<String, Channel>> allChannelsByIdMapProvider =
    StreamProvider.autoDispose<Map<String, Channel>>((ref) {
      if (!ref.watch(isSeedDatabaseReadyProvider)) {
        return const Stream<Map<String, Channel>>.empty();
      }
      final databaseService = ref.watch(databaseServiceProvider);
      return databaseService.watchAllChannels().map(
        (list) => {for (final c in list) c.id: c},
      );
    });
