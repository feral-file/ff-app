import 'package:app/app/providers/address_indexing_job_provider.dart';
import 'package:app/widgets/playlist/indexing_status_text.dart';
import 'package:app/widgets/playlist/playlist_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Playlist header that can display an optional "collection sync" status.
///
/// When [ownerAddress] is provided, watches [addressIndexingProcessStatusProvider]
/// and [indexingJobStatusProvider], then derives status text via
/// [deriveIndexingStatusText] (e.g. "Syncing • X ready • Y found").
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
    this.subtitle,
    this.onSubtitleTap,
    this.trailing,
    this.showDivider = false,
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

  /// Optional subtitle (e.g. channel name).
  final String? subtitle;

  /// Tap handler for the subtitle line.
  final VoidCallback? onSubtitleTap;

  /// Optional trailing widget (e.g. options menu button).
  final Widget? trailing;

  /// When true, uses detail-page style (divider below, hide secondary).
  final bool showDivider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var effectiveStatusText = statusText;
    var effectiveShowRetry = false;

    if (ownerAddress != null && ownerAddress!.isNotEmpty) {
      final processStatusAsync = ref.watch(
        addressIndexingProcessStatusProvider(ownerAddress!),
      );
      final job = ref.watch(indexingJobStatusProvider(ownerAddress!));
      final processStatus = processStatusAsync.hasValue
          ? processStatusAsync.value
          : null;
      final derived = deriveIndexingStatusText(
        processStatus: processStatus,
        job: job,
        readyCount: total,
      );
      effectiveStatusText = derived.text;
      effectiveShowRetry = derived.showRetry;
    }

    final isAddressPlaylist = ownerAddress != null && ownerAddress!.isNotEmpty;

    // Address playlists (list rows): swap which string fills [PlaylistTitle]'s
    // secondary vs status slots so indexing text sits on the title row and the
    // address sits on the lower line. Detail headers use [showDivider], which
    // hides secondary—keep the original mapping so status stays the second line.
    final String titleSecondary;
    final String? titleStatus;
    if (isAddressPlaylist && !showDivider) {
      titleSecondary = effectiveStatusText ?? '';
      titleStatus = secondaryText.isEmpty ? null : secondaryText;
    } else {
      titleSecondary = secondaryText;
      titleStatus = effectiveStatusText;
    }

    return PlaylistTitle(
      primaryText: primaryText,
      secondaryText: titleSecondary,
      statusText: titleStatus,
      onTap: onTap,
      onRetry: effectiveShowRetry ? onRetry : null,
      subtitle: subtitle,
      onSubtitleTap: onSubtitleTap,
      trailing: trailing,
      showDivider: showDivider,
    );
  }
}
