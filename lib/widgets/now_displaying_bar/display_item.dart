import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/playlist_item.dart';
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
                        style: AppTypography.bodySmall(context).white,
                      ),
                      Transform.translate(
                        offset: Offset(
                          0,
                          LayoutConstants
                              .nowDisplayingDisplayItemTextArtworkGap,
                        ),
                        child: Text(
                          item.title ?? 'Unknown title',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: isInExpandedView
                              ? AppTypography.bodySmall(
                                  context,
                                ).white.bold.italic
                              : AppTypography.bodySmall(context).white,
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
            ? const _ThumbnailPlaceholder()
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const _ThumbnailPlaceholder(),
                errorWidget: (_, __, ___) => const _ThumbnailPlaceholder(),
              ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PrimitivesTokens.colorsDarkGrey,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: LayoutConstants.iconSizeMedium,
          color: PrimitivesTokens.colorsLightGrey,
        ),
      ),
    );
  }
}
