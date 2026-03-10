import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/gallery_thumbnail_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger('WorkItemThumbnail');

/// Work item thumbnail used in DP-1 carousels.
/// Uses domain [PlaylistItem] only.
class WorkItemThumbnail extends StatelessWidget {
  /// Creates a [WorkItemThumbnail].
  const WorkItemThumbnail({
    required this.item,
    this.onTap,
    super.key,
  });

  /// Work item (domain).
  final PlaylistItem item;

  /// Optional tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: LayoutConstants.workThumbnailContainerWidth,
        height: LayoutConstants.workThumbnailContainerHeight,
        padding: const EdgeInsets.all(
          LayoutConstants.workThumbnailContainerPadding,
        ),
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: LayoutConstants.workThumbnailImageWidth,
          height: LayoutConstants.workThumbnailImageHeight,
          child: _buildThumbnail(),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final thumbnailUrl = item.thumbnailUrl;
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      // Show loading placeholder when thumbnail is missing
      // (enrichment in progress)
      // _log.fine('Thumbnail URL is empty for work: ${item.id}, showing loading placeholder');
      return const GalleryThumbnailPlaceholder();
    }

    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => const GalleryThumbnailPlaceholder(),
      errorWidget: (context, url, error) {
        _log.warning('Failed to load thumbnail for work ${item.id}: $error');
        return const GalleryThumbnailErrorWidget();
      },
    );
  }
}
