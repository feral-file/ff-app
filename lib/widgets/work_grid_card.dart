import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/playlist_item_ext.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/widgets/gallery_thumbnail_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger('WorkGridCard');

/// Grid card for displaying a work (domain [PlaylistItem]).
class WorkGridCard extends StatelessWidget {
  /// Creates a [WorkGridCard].
  const WorkGridCard({
    required this.item,
    required this.onTap,
    super.key,
  });

  /// Work to display (domain).
  final PlaylistItem item;

  /// Tap handler.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.title;
    final artistName = item.subtitle ?? item.artistName;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.all(LayoutConstants.space3),
        child: IgnorePointer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return ClipRect(
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Center(child: _buildThumbnail()),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: LayoutConstants.space2),
              Text(
                title,
                style: AppTypography.bodySmall(context).white,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (artistName.isNotEmpty) ...[
                SizedBox(height: LayoutConstants.space1),
                Text(
                  artistName,
                  style: AppTypography.bodySmall(context).grey.italic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final url = item.thumbnailUrl;
    if (url == null || url.isEmpty) {
      return const GalleryThumbnailErrorWidget();
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.contain,
      placeholder: (context, url) => const GalleryThumbnailPlaceholder(),
      errorWidget: (context, url, error) {
        _log.warning('Failed to load thumbnail for work ${item.id}: $error');
        return const GalleryThumbnailErrorWidget();
      },
    );
  }
}
