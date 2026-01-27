import 'package:app/widgets/dp1_carousel.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final _log = Logger('DP1ItemThumbnail');

/// Token values for ArtworkItem layout
class ArtworkItemTokens {
  /// Container width including padding.
  static const double containerWidth = 245;

  /// Container height including padding.
  static const double containerHeight = 285;

  /// Padding within the container.
  static const double containerPadding = 0;

  /// Image width.
  static const double imageWidth = 245;

  /// Image height.
  static const double imageHeight = 285;
}

/// DP1 Item Thumbnail - Displays a single work thumbnail
class DP1ItemThumbnail extends StatelessWidget {
  /// Creates a DP1ItemThumbnail.
  const DP1ItemThumbnail({
    required this.item,
    this.onTap,
    super.key,
  });

  /// Work item data.
  final WorkItemData item;

  /// Callback when tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: ArtworkItemTokens.containerWidth,
        height: ArtworkItemTokens.containerHeight,
        padding: EdgeInsets.zero,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        alignment: Alignment.center,
        child: SizedBox(
          width: ArtworkItemTokens.imageWidth,
          height: ArtworkItemTokens.imageHeight,
          child: _buildThumbnail(context),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final thumbnailUrl = item.thumbnailUrl;

    if (thumbnailUrl.isEmpty) {
      _log.info('Thumbnail URL is empty for work: ${item.workId}');
      return const GalleryNoThumbnailWidget();
    }

    _log.info('Loading thumbnail for work ${item.workId}: $thumbnailUrl');

    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
      errorWidget: (context, url, error) {
        _log.warning(
          'Failed to load thumbnail for work ${item.workId}: $error',
        );
        return const GalleryNoThumbnailWidget();
      },
    );
  }
}

/// Widget displayed when no thumbnail is available
class GalleryNoThumbnailWidget extends StatelessWidget {
  /// Creates a GalleryNoThumbnailWidget.
  const GalleryNoThumbnailWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF2E2E2E),
      child: Center(
        child: Icon(
          Icons.image_not_supported,
          color: Color(0xFFA0A0A0),
          size: 48,
        ),
      ),
    );
  }
}
