import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Publisher id → display title for playlist section headers.
///
/// Auto-dispose so DB watch is not kept alive after leaving All Playlists.
final StreamProvider<Map<int, String>> publisherTitlesMapProvider =
    StreamProvider.autoDispose<Map<int, String>>((ref) {
  if (!ref.watch(isSeedDatabaseReadyProvider)) {
    return Stream.value(const {});
  }
  final databaseService = ref.watch(databaseServiceProvider);
  return databaseService.watchPublisherTitles();
});

/// All channels keyed by id (for resolving playlist.channelId → publisher).
///
/// Auto-dispose so DB watch is not kept alive after leaving All Playlists.
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
