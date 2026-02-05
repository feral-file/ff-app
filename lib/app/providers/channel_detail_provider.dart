import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

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
final channelDetailsProvider =
    FutureProvider.family<ChannelDetails, String>((ref, channelId) async {
  final log = Logger('channelDetailsProvider');

  try {
    final databaseService = ref.read(databaseServiceProvider);
    final channel = await databaseService.getChannelById(channelId);
    final playlists =
        await databaseService.getPlaylistsByChannel(channelId);
    return ChannelDetails(channel: channel, playlists: playlists);
  } catch (e, stack) {
    log.severe('Failed to load channel details for $channelId', e, stack);
    rethrow;
  }
});

