import 'package:app/design/app_typography.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/gallery_thumbnail_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Display item for Now Displaying bar (collapsed and expanded).
///
/// Matches old repo DisplayItem: landscape thumbnail, optional device name,
/// artist + title with bold.italic in expanded view.
class NowDisplayingDisplayItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final opacity = isPlaying ? 1.0 : 0.5;

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Row(
          crossAxisAlignment: isInExpandedView
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            _Thumbnail(url: item.thumbnailUrl),
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
                      style: AppTypography.displayItemDeviceName(context).white,
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
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: LayoutConstants.nowDisplayingDisplayItemThumbWidth,
      height: LayoutConstants.nowDisplayingDisplayItemThumbHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LayoutConstants.space1),
        child: url == null || url!.isEmpty
            ? const GalleryNoThumbnailWidget()
            : CachedNetworkImage(
                imageUrl: url!,
                memCacheWidth: (LayoutConstants.nowDisplayingDisplayItemThumbWidth *
                        2)
                    .round(),
                memCacheHeight: (LayoutConstants.nowDisplayingDisplayItemThumbHeight *
                        2)
                    .round(),
                fit: BoxFit.cover,
                placeholder: (_, _) => const GalleryThumbnailPlaceholder(),
                errorWidget: (_, _, _) => const GalleryThumbnailErrorWidget(),
              ),
      ),
    );
  }
}
