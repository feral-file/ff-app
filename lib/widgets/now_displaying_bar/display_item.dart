import 'package:app/app/providers/playback_progress_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/image_decode_cache.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/gallery_thumbnail_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Display item for Now Displaying bar (collapsed and expanded).
///
/// Matches old repo DisplayItem: landscape thumbnail, optional device name,
/// artist + title with bold.italic in expanded view.
class NowDisplayingDisplayItem extends ConsumerWidget {
  const NowDisplayingDisplayItem({
    required this.item,
    required this.isPlaying,
    this.deviceName,
    this.isInExpandedView = false,
    this.onTap,
    super.key,
  });

  final PlaylistItem item;
  final String? deviceName;
  final bool isPlaying;
  final bool isInExpandedView;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opacity = isPlaying ? 1.0 : 0.5;
    final progressState = ref.watch(playbackProgressProvider);
    final progress = progressState.itemId == item.id
        ? progressState.progress
        : null;

    // Transparent fill matches e.g. [WorkGridCard]: full-bounds hit target so
    // taps register outside text/thumbnail (Row flex padding).
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: ColoredBox(
          color: Colors.transparent,
          child: Row(
            crossAxisAlignment: isInExpandedView
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              _Thumbnail(url: item.thumbnailUrl, progress: progress),
              SizedBox(width: LayoutConstants.nowDisplayingDisplayItemGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (deviceName != null)
                      Text(
                        deviceName!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppTypography.displayItemDeviceName(context).white,
                      ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ContentRhythm.supporting(
                            context,
                          ).copyWith(color: Colors.white),
                        ),
                        Transform.translate(
                          offset: const Offset(
                            0,
                            LayoutConstants
                                .nowDisplayingDisplayItemTextArtworkGap,
                          ),
                          child: Text(
                            item.title ?? 'Unknown title',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: isInExpandedView
                                ? ContentRhythm.supporting(
                                    context,
                                  ).copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontStyle: FontStyle.italic,
                                  )
                                : ContentRhythm.supporting(
                                    context,
                                  ).copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url, this.progress});

  final String? url;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const thumbW = LayoutConstants.nowDisplayingDisplayItemThumbWidth;
    const thumbH = LayoutConstants.nowDisplayingDisplayItemThumbHeight;

    return SizedBox(
      width: thumbW,
      height: thumbH,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LayoutConstants.space1),
        child: Stack(
          children: [
            Positioned.fill(
              child: url == null || url!.isEmpty
                  ? const GalleryNoThumbnailWidget()
                  : CachedNetworkImage(
                      imageUrl: url!,
                      width: thumbW,
                      height: thumbH,
                      memCacheWidth:
                          decodePixelsForLogicalSize(thumbW, dpr),
                      memCacheHeight:
                          decodePixelsForLogicalSize(thumbH, dpr),
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      placeholder: (_, _) =>
                          const GalleryThumbnailPlaceholder(),
                      errorWidget: (_, _, _) =>
                          const GalleryThumbnailErrorWidget(),
                    ),
            ),
            if (progress != null)
              Positioned(
                bottom: 2,
                left: 2,
                right: 2,
                child: _ProgressBar(progress: progress!),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(
          builder: (_, constraints) {
            final trackWidth = constraints.maxWidth;
            final fillWidth =
                trackWidth * progress.clamp(0.0, 1.0);
            return SizedBox(
              height: 2,
              child: Stack(
                children: [
                  Container(
                    width: trackWidth,
                    height: 2,
                    color: const Color(0xFF2E2E2E),
                  ),
                  Container(
                    width: fillWidth,
                    height: 2,
                    color: Colors.white,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
