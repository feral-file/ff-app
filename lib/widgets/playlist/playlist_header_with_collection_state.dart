import 'package:app/app/providers/address_indexing_job_provider.dart';
import 'package:app/widgets/playlist/indexing_status_text.dart';
import 'package:app/widgets/playlist/playlist_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Playlist header that can display an optional "collection sync" status.
///
/// When [ownerAddress] is provided, watches [indexingJobStatusProvider] and
/// derives status text (e.g. "Syncing • X ready • Y found") via
/// [deriveIndexingStatusText].
///
/// When [ownerAddress] is null, uses [statusText] if provided (manual override).
class PlaylistHeaderWithCollectionState extends ConsumerWidget {
  /// Creates a [PlaylistHeaderWithCollectionState].
  const PlaylistHeaderWithCollectionState({
    required this.primaryText,
    required this.secondaryText,
    this.total,
    this.ownerAddress,
    this.statusText,
    this.onTap,
    this.onRetry,
    super.key,
  });

  /// Primary line text (playlist title).
  final String primaryText;

  /// Secondary line text (creator, address, etc.).
  final String secondaryText;

  /// Optional total number of works (used as readyCount for indexing status).
  final int? total;

  /// Optional owner address for address-based playlists.
  /// When set, status is derived from [indexingJobStatusProvider].
  final String? ownerAddress;

  /// Optional status text override (used when [ownerAddress] is null).
  final String? statusText;

  /// Tap handler.
  final VoidCallback? onTap;

  /// Retry handler (shown when indexing failed/canceled).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var effectiveStatusText = statusText;
    var effectiveShowRetry = false;

    if (ownerAddress != null && ownerAddress!.isNotEmpty) {
      final job = ref.watch(indexingJobStatusProvider(ownerAddress!));
      final derived = deriveIndexingStatusText(
        job: job,
        readyCount: total,
      );
      effectiveStatusText = derived.text;
      effectiveShowRetry = derived.showRetry;
    }

    return PlaylistTitle(
      primaryText: primaryText,
      secondaryText: secondaryText,
      total: total,
      statusText: effectiveStatusText,
      onTap: onTap,
      onRetry: effectiveShowRetry ? onRetry : null,
    );
  }
}
