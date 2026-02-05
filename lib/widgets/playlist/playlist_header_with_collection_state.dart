import 'package:app/widgets/playlist/playlist_title.dart';
import 'package:flutter/material.dart';

/// Playlist header that can display an optional “collection sync” status.
///
/// This mirrors the old app’s intent without coupling UI to a specific sync
/// implementation. Feed any status text via [statusText].
class PlaylistHeaderWithCollectionState extends StatelessWidget {
  /// Creates a [PlaylistHeaderWithCollectionState].
  const PlaylistHeaderWithCollectionState({
    required this.primaryText,
    required this.secondaryText,
    this.total,
    this.statusText,
    this.onTap,
    this.onRetry,
    super.key,
  });

  /// Primary line text (playlist title).
  final String primaryText;

  /// Secondary line text (creator, address, etc.).
  final String secondaryText;

  /// Optional total number of works.
  final int? total;

  /// Optional status text (e.g., syncing, paused, issue).
  final String? statusText;

  /// Tap handler.
  final VoidCallback? onTap;

  /// Retry handler (shown if [statusText] is provided).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return PlaylistTitle(
      primaryText: primaryText,
      secondaryText: secondaryText,
      total: total,
      statusText: statusText,
      onTap: onTap,
      onRetry: onRetry,
    );
  }
}

