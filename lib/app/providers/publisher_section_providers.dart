import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_publisher.dart';
import 'package:riverpod/misc.dart';
import 'package:riverpod/riverpod.dart';

/// Publisher sections for the all-channels view.
///
/// This keeps the screen focused on rendering, while the grouping and section
/// metadata stay in one place.
final StreamProvider<List<DP1Publisher>> publishersProvider =
    StreamProvider.autoDispose<List<DP1Publisher>>((ref) {
      if (!ref.watch(isSeedDatabaseReadyProvider)) {
        // Keep the provider pending until the seed DB is ready so browse
        // screens stay in a retryable loading state instead of collapsing
        // into a false empty result during first-install bootstrap.
        return const Stream<List<DP1Publisher>>.empty();
      }
      final databaseService = ref.watch(databaseServiceProvider);
      return databaseService.watchPublishers();
    });

/// Publisher id → display title for section headers.
///
/// When the seed DB is not ready, emits [Stream.value] with an empty map (the
/// async state completes with `hasValue`). For layout gating, pair with
/// [allChannelsByIdMapProvider], which does **not** emit until ready—so
/// combined lookup readiness stays false during bootstrap.
final StreamProvider<Map<int, String>> publisherTitlesMapProvider =
    StreamProvider.autoDispose<Map<int, String>>((ref) {
  if (!ref.watch(isSeedDatabaseReadyProvider)) {
    return Stream.value(const {});
  }
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.watchPublisherTitles();
});

/// Channels belonging to one publisher, preserving source order.
///
/// The family argument `publisherId` is nullable so the curated screen can
/// also render channels without a publisher bucket.
final StreamProviderFamily<List<Channel>, int?> channelsByPublisherProvider =
    StreamProvider.autoDispose.family<List<Channel>, int?>((ref, publisherId) {
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
/// When the seed DB is not ready, returns a non-emitting stream so the async
/// value stays **loading** (contrast: [publisherTitlesMapProvider] completes
/// with an empty map). All Playlists uses this with
/// [isSeedDatabaseReadyProvider] so grouped layout does not run on a false
/// empty channel map.
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
