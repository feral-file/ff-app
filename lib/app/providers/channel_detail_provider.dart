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
