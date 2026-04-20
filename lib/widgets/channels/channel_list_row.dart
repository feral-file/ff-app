import 'dart:async';

import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/app/providers/channel_preview_provider.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/channel_item.dart';
import 'package:app/widgets/dp1_carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Data model for a channel row (domain only).
class ChannelRowData {
  /// Creates ChannelRowData.
  const ChannelRowData({
    required this.channelId,
    required this.channelTitle,
    required this.works,
    this.channelSummary,
    this.showUnseenUpdateDot = false,
  });

  /// Channel ID.
  final String channelId;

  /// Channel title.
  final String channelTitle;

  /// Optional channel summary.
  final String? channelSummary;

  /// List of works in this channel (domain).
  /// When empty, [ChannelListRow] loads preview via [channelPreviewProvider].
  final List<PlaylistItem> works;

  /// Living-channel: pulsing red dot until the user opens channel details.
  final bool showUnseenUpdateDot;
}

/// Channel List Row - Combines channel info with carousel of works.
/// When [ChannelRowData.works] is empty, uses [channelPreviewProvider] to load
/// and page preview works for the channel.
class ChannelListRow extends ConsumerStatefulWidget {
  /// Creates a ChannelListRow.
  const ChannelListRow({
    required this.channelData,
    this.onItemTap,
    this.isActive = true,
    super.key,
  });

  /// Channel data to display.
  final ChannelRowData channelData;

  /// Callback when a work item is tapped.
  final void Function(PlaylistItem item)? onItemTap;

  /// Whether this row should actively listen to providers.
  final bool isActive;

  @override
  ConsumerState<ChannelListRow> createState() => _ChannelListRowState();
}

class _ChannelListRowState extends ConsumerState<ChannelListRow> {
  ChannelPreviewState _cachedPreviewState = ChannelPreviewState.initial();

  @override
  void didUpdateWidget(ChannelListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelData.channelId != widget.channelData.channelId) {
      _cachedPreviewState = ChannelPreviewState.initial();
    }
    if (!oldWidget.isActive &&
        widget.isActive &&
        widget.channelData.works.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.isActive) return;
        unawaited(
          ref
              .read(
                channelPreviewProvider(widget.channelData.channelId).notifier,
              )
              .load(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelId = widget.channelData.channelId;
    final nextPreviewState = widget.isActive
        ? ref.watch(channelPreviewProvider(channelId))
        : _cachedPreviewState;

    // When the autoDispose provider is recreated after a tab switch it returns
    // initial() — isLoading: false, works: [], hasMore: true — before the DB
    // watch delivers data. Keep showing cached works during that gap to avoid
    // a height collapse that makes the list jumpy. Do NOT keep cached when
    // nextPreviewState has hasMore: false (loaded and legitimately empty, e.g.
    // after removing an address); that would show stale works.
    final shouldKeepCached =
        widget.isActive &&
        _cachedPreviewState.works.isNotEmpty &&
        nextPreviewState.works.isEmpty &&
        nextPreviewState.hasMore &&
        nextPreviewState.error == null;

    final previewState = shouldKeepCached
        ? _cachedPreviewState
        : nextPreviewState;
    if (widget.isActive && !shouldKeepCached) {
      _cachedPreviewState = nextPreviewState;
    }

    final works = widget.channelData.works.isNotEmpty
        ? widget.channelData.works
        : previewState.works;
    final hasMore = widget.channelData.works.isEmpty && previewState.hasMore;
    final isLoadingMore =
        widget.channelData.works.isEmpty && previewState.isLoadingMore;
    // Show loading skeleton when works empty and we're in preview mode, unless
    // we've finished loading with no items (hasMore false) or hit an error.
    // initial() has isLoading=false — show skeleton anyway to prevent bounce
    // before load() sets isLoading=true.
    final isLoading =
        widget.channelData.works.isEmpty &&
        works.isEmpty &&
        (previewState.isLoading ||
            (previewState.hasMore && previewState.error == null));
    final error = widget.channelData.works.isEmpty ? previewState.error : null;

    return Container(
      key: GoldPathPatrolKeys.channelRow(channelId),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(),
        ),
      ),
      padding: EdgeInsets.only(bottom: LayoutConstants.space3),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChannelHeader(
                channelId: widget.channelData.channelId,
                channelTitle: widget.channelData.channelTitle,
                channelSummary: widget.channelData.channelSummary,
                maxLines: 4,
              ),
              if (error != null)
                Padding(
                  padding:
                      EdgeInsets.only(top: ContentRhythm.rowVerticalPadding),
                  child: Text(
                    "We couldn't load this channel's works. Tap to retry.",
                    style: ContentRhythm.supporting(context),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: EdgeInsets.only(top: LayoutConstants.space2),
                  child: TextButton(
                    onPressed: () {
                      unawaited(
                        ref
                            .read(channelPreviewProvider(channelId).notifier)
                            .load(),
                      );
                    },
                    child: Text(
                      'Retry',
                      style: ContentRhythm.controlLabel(context),
                    ),
                  ),
                ),
              DP1Carousel(
                items: works,
                isLoading: isLoading && works.isEmpty,
                onItemTap: widget.onItemTap,
                itemKeyBuilder: (item, _) => GoldPathPatrolKeys.channelWork(
                  channelId: channelId,
                  workId: item.id,
                ),
                isLoadingMore: isLoadingMore,
                onLoadMore: hasMore
                    ? () {
                        unawaited(
                          ref
                              .read(
                                channelPreviewProvider(channelId).notifier,
                              )
                              .loadMore(),
                        );
                      }
                    : null,
              ),
            ],
          ),
          if (widget.channelData.showUnseenUpdateDot)
            const Positioned(
              top: 4,
              right: 8,
              child: _LivingUnseenDot(),
            ),
        ],
      ),
    );
  }
}

class _LivingUnseenDot extends StatefulWidget {
  const _LivingUnseenDot();

  @override
  State<_LivingUnseenDot> createState() => _LivingUnseenDotState();
}

class _LivingUnseenDotState extends State<_LivingUnseenDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    unawaited(_controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFFFF0000),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
