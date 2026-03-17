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
      final databaseService = ref.read(databaseServiceProvider);

      return Rx.combineLatest2<Channel?, List<Playlist>, ChannelDetails>(
        databaseService.watchChannelById(channelId),
        databaseService.watchPlaylists(channelId: channelId),
        (channel, playlists) =>
            ChannelDetails(channel: channel, playlists: playlists),
      );
    });

/// Provider for playlists across multiple channels.
/// Key is comma-joined channel IDs (e.g. "id1,id2").
final StreamProviderFamily<List<Playlist>, String>
    channelPlaylistsFromIdsProvider =
    StreamProvider.family<List<Playlist>, String>((ref, channelIdsKey) {
      final databaseService = ref.read(databaseServiceProvider);
      final ids = channelIdsKey.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (ids.isEmpty) return Stream.value(<Playlist>[]);
      if (ids.length == 1) {
        return databaseService.watchPlaylists(channelId: ids.single);
      }
      final streams = ids.map((id) => databaseService.watchPlaylists(channelId: id));
      return Rx.combineLatest<List<Playlist>, List<Playlist>>(
        streams,
        (list) => list.expand((x) => x).toList(),
      );
    });
