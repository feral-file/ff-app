import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:riverpod/src/providers/stream_provider.dart';
import 'package:rxdart/rxdart.dart';

/// View model for channel details (domain only).
class ChannelDetails {
  const ChannelDetails({
    required this.channel,
    required this.playlists,
  });

  /// Channel being viewed.
  final Channel? channel;

  /// Playlists in the channel (domain).
  final List<Playlist> playlists;
}

/// Provider for channel details state.
/// Watches the database so the UI updates when channel or playlists change.
final StreamProviderFamily<ChannelDetails, String> channelDetailsProvider =
    StreamProvider.family<ChannelDetails, String>((ref, channelId) {
      if (!ref.watch(isSeedDatabaseReadyProvider)) {
        return Stream.value(
          const ChannelDetails(channel: null, playlists: []),
        );
      }
      final databaseService = ref.read(databaseServiceProvider);

      return Rx.combineLatest2<Channel?, List<Playlist>, ChannelDetails>(
        databaseService.watchChannelById(channelId),
        databaseService.watchPlaylists(channelIds: [channelId]),
        (channel, playlists) {
          final withWorks = playlists
              .where((p) => p.itemCount > 0 || p.isAddressPlaylist)
              .toList();
          return ChannelDetails(channel: channel, playlists: withWorks);
        },
      );
    });

/// Provider for playlists across multiple channels.
/// Key is comma-joined channel IDs (e.g. "id1,id2").
/// Uses a single DB query with channelIds so order matches canonical
/// publisher_id, created_at_us semantics.
final StreamProviderFamily<List<Playlist>, String>
channelPlaylistsFromIdsProvider = StreamProvider.family<List<Playlist>, String>(
  (ref, channelIdsKey) {
    final databaseService = ref.read(databaseServiceProvider);
    final ids = channelIdsKey
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (ids.isEmpty) return Stream.value(<Playlist>[]);
    return databaseService
        .watchPlaylists(channelIds: ids)
        .map(
          (list) => list
              .where((p) => p.itemCount > 0 || p.isAddressPlaylist)
              .toList(),
        );
  },
);
