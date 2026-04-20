import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/dp1_feed_api_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/services/living_channel_polling_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ingest + follow helpers (e.g. discovery / first-time follow).
final livingChannelFollowActionsProvider =
    Provider<LivingChannelFollowActions>((ref) {
  return LivingChannelFollowActions(ref);
});

/// Coordinates DP-1 Feed fetch + local ingest + [DatabaseService.followChannel].
class LivingChannelFollowActions {
  /// Creates actions with a [Ref] for providers.
  LivingChannelFollowActions(this._ref);

  final Ref _ref;

  String _normalizedFeedBase() {
    final raw = AppConfig.dp1FeedUrl.trim();
    if (raw.isEmpty) {
      return '';
    }
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  /// Fetches channel + playlists from the feed, persists, then follows locally.
  Future<void> addChannelFromFeedAndFollow(String channelId) async {
    final base = _normalizedFeedBase();
    if (base.isEmpty) {
      throw StateError('DP1_FEED_URL is not configured');
    }
    final api = _ref.read(dp1FeedApiProvider);
    final db = _ref.read(databaseServiceProvider);
    final wire = await api.getChannelById(channelId);
    final playlists = await fetchAllPlaylistsForChannel(api, channelId);
    await db.ingestDP1ChannelWithPlaylistsBare(
      baseUrl: base,
      channel: wire,
      playlists: playlists,
      channelType: ChannelType.dp1,
    );
    await db.followChannel(channelId);
    _ref.invalidate(channelsProvider(ChannelType.living));
    _ref.invalidate(channelsProvider(ChannelType.dp1));
  }
}
