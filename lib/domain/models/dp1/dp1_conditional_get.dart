import 'package:app/domain/models/dp1/dp1_channel.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:meta/meta.dart';

/// Result of a conditional GET (ETag / If-None-Match) against DP-1 Feed.
@immutable
class ConditionalChannelGet {
  /// Creates a conditional channel GET result.
  const ConditionalChannelGet({
    required this.notModified,
    this.channel,
    this.etag,
  });

  /// True when server returned 304 Not Modified.
  final bool notModified;

  /// Parsed channel body when status was 200.
  final DP1Channel? channel;

  /// Value of `ETag` response header (200 or 304).
  final String? etag;
}

/// Result of a conditional GET for a single playlist.
@immutable
class ConditionalPlaylistGet {
  /// Creates a conditional playlist GET result.
  const ConditionalPlaylistGet({
    required this.notModified,
    this.playlist,
    this.etag,
  });

  /// True when server returned 304 Not Modified.
  final bool notModified;

  /// Parsed playlist body when status was 200.
  final DP1Playlist? playlist;

  /// Value of `ETag` response header (200 or 304).
  final String? etag;
}
