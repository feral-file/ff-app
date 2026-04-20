import 'dart:async';

import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/services/living_channel_change_detector.dart';
import 'package:app/infra/api/dp1_feed_api.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:logging/logging.dart';

/// Polls **followed** living channels only (`followed_channels` ⋈ `channels`).
///
/// The Living **tab** lists the full living catalog from seed/sync; this
/// service does not iterate every living channel — only those the user chose
/// to follow, on a timer while foregrounded.
class LivingChannelPollingService {
  /// Creates the service.
  LivingChannelPollingService({
    required DP1FeedApi api,
    required DatabaseService databaseService,
    required this.feedBaseUrl,
    required this.onChanges,
  })  : _api = api,
        _db = databaseService,
        _log = Logger('LivingChannelPollingService');

  final DP1FeedApi _api;
  final DatabaseService _db;
  final Logger _log;

  /// Normalized feed origin (no trailing slash).
  final String feedBaseUrl;

  /// Called when [LivingChannelChangeDetector] finds updates after a successful
  /// persist. Only invoked when [FollowedChannelData.initialPollDone] is non-zero.
  final void Function(
    String channelId,
    List<LivingChannelChange> changes,
    String summaryMessage,
    String? playPlaylistId,
  ) onChanges;

  Timer? _timer;
  static const Duration _period = Duration(minutes: 1);

  /// Starts periodic polling (idempotent).
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_period, (_) {
      unawaited(pollAllFollowed());
    });
  }

  /// Stops periodic polling.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// One-shot poll (e.g. on resume).
  Future<void> pollAllFollowed() async {
    final rows = await _db.getFollowedChannelsJoined();
    for (final row in rows) {
      final channelId = row.$1.id;
      try {
        await pollChannel(channelId);
      } on Object catch (e, st) {
        _log.fine('Living poll failed for $channelId: $e', e, st);
      }
    }
  }

  /// Polls a single channel (full conditional GET + ingest + diff).
  Future<void> pollChannel(String channelId) async {
    final follow = await _db.getFollowedChannelRow(channelId);
    if (follow == null) {
      return;
    }

    final oldChannel = await _db.getChannelById(channelId);
    if (oldChannel == null) {
      return;
    }
    final oldSnap = await _db.loadPlaylistPollSnapshots(channelId);

    final chCond = await _api.getChannelByIdConditional(
      channelId,
      ifNoneMatch: oldChannel.etag,
    );
    final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
    await _db.updateFollowedChannelPollMeta(
      channelId: channelId,
      lastPolledAtUs: nowUs,
    );

    if (chCond.notModified) {
      return;
    }
    final wireChannel = chCond.channel;
    final channelEtag = chCond.etag;
    if (wireChannel == null) {
      return;
    }

    final listed = await _fetchAllPlaylistsForChannel(channelId);
    final playlistEtagById = <String, String>{};
    final toIngest = <DP1Playlist>[];

    for (final listedPl in listed) {
      final existing = await _db.getPlaylistById(listedPl.id);
      final ifNone = existing?.etag;
      final plCond = await _api.getPlaylistByIdConditional(
        listedPl.id,
        ifNoneMatch: ifNone,
      );
      final etag = plCond.etag ?? ifNone;
      if (etag != null) {
        playlistEtagById[listedPl.id] = etag;
      }
      if (plCond.notModified) {
        final snap = await _db.dp1PlaylistSnapshotFromDb(listedPl.id);
        toIngest.add(snap);
      } else if (plCond.playlist != null) {
        toIngest.add(plCond.playlist!);
      }
    }

    await _db.ingestDP1ChannelWithPlaylistsBare(
      baseUrl: feedBaseUrl,
      channel: wireChannel,
      playlists: toIngest,
      publisherId: oldChannel.publisherId,
      channelType: ChannelType.living,
      channelEtag: channelEtag,
      playlistEtagById: playlistEtagById,
    );

    final newChannel = await _db.getChannelById(channelId);
    if (newChannel == null) {
      return;
    }
    final newSnap = await _db.loadPlaylistPollSnapshots(channelId);

    final changes = LivingChannelChangeDetector.detect(
      oldChannel: oldChannel,
      newChannel: newChannel,
      oldByPlaylistId: oldSnap,
      newByPlaylistId: newSnap,
    );

    final hadCompletedInitial = follow.initialPollDone != 0;
    await _db.updateFollowedChannelPollMeta(
      channelId: channelId,
      initialPollDone: true,
    );

    if (!hadCompletedInitial) {
      return;
    }

    if (changes.isEmpty) {
      return;
    }

    await _db.markFollowedChannelUnseenUpdate(
      channelId,
      hasUnseen: true,
    );
    final message = _formatSummary(newChannel.name, changes);
    final playId = _pickPlayPlaylistId(changes);
    onChanges(channelId, changes, message, playId);
  }

  String _formatSummary(String channelName, List<LivingChannelChange> changes) {
    if (changes.isEmpty) {
      return channelName;
    }
    final parts = changes.take(3).map(_formatOne).toList();
    final more = changes.length > 3 ? ' (+${changes.length - 3} more)' : '';
    return '${channelName}: ${parts.join('; ')}$more';
  }

  String _formatOne(LivingChannelChange c) {
    switch (c.type) {
      case LivingChannelChangeType.newPlaylistAdded:
        return 'New playlist "${c.playlistName ?? c.playlistId}"';
      case LivingChannelChangeType.newWorkAdded:
        return 'New work in "${c.playlistName ?? c.playlistId}"';
      case LivingChannelChangeType.playlistNoteUpdated:
        return 'Note updated on "${c.playlistName ?? c.playlistId}"';
    }
  }

  String? _pickPlayPlaylistId(List<LivingChannelChange> changes) {
    for (final c in changes) {
      if (c.playlistId != null) {
        return c.playlistId;
      }
    }
    return null;
  }

  Future<List<DP1Playlist>> _fetchAllPlaylistsForChannel(
    String channelId,
  ) async {
    return fetchAllPlaylistsForChannel(_api, channelId);
  }
}

/// Paginates `GET /api/v1/playlists?channel=…` until exhausted.
Future<List<DP1Playlist>> fetchAllPlaylistsForChannel(
  DP1FeedApi api,
  String channelId,
) async {
  final out = <DP1Playlist>[];
  String? cursor;
  do {
    final page = await api.getPlaylists(
      channelId: channelId,
      cursor: cursor,
      limit: 100,
    );
    out.addAll(page.items);
    cursor = page.hasMore ? page.cursor : null;
  } while (cursor != null);
  return out;
}
