import 'dart:math' as math;

import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

/// Placeholder widget for gallery thumbnails with shimmer effect.
/// Used when loading images in CachedNetworkImage.
class GalleryThumbnailPlaceholder extends StatelessWidget {
  /// Creates a [GalleryThumbnailPlaceholder].
  const GalleryThumbnailPlaceholder({
    super.key,
    this.loading = true,
  });

  /// Whether this is a loading state.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: loading ? 'Loading' : '',
      child: AspectRatio(
        aspectRatio: 1,
        child: Shimmer.fromColors(
          baseColor: Colors.transparent,
          highlightColor: Colors.white.withAlpha(10),
          period: const Duration(milliseconds: 1000),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(0),
            ),
          ),
        ),
      ),
    );
  }
}

/// Error widget for gallery thumbnails.
/// Used when image loading fails in CachedNetworkImage.
class GalleryThumbnailErrorWidget extends StatelessWidget {
  /// Creates a [GalleryThumbnailErrorWidget].
  const GalleryThumbnailErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(LayoutConstants.space2),
      color: AppColor.auGreyBackground,
      child: Stack(
        children: [
          Center(
            child: SvgPicture.asset(
              'assets/images/ipfs_error_icon.svg',
              width: LayoutConstants.space6,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: Text(
              'Not available',
              style: AppTypography.verySmall(context).bold.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying "no thumbnail" state with appropriate icon.
/// Used when there's no thumbnail available for a work item.
class GalleryNoThumbnailWidget extends StatelessWidget {
  /// Creates a [GalleryNoThumbnailWidget].
  const GalleryNoThumbnailWidget({
    this.mimeType,
    super.key,
  });

  /// Optional MIME type to determine which icon to show.
  /// Supported values: 'modelViewer', 'webview', 'video'
  /// If null or not matching, shows default no_thumbnail icon.
  final String? mimeType;

  String _getAssetDefault() {
    switch (mimeType) {
      case 'modelViewer':
        return 'assets/images/icon_3d.svg';
      case 'webview':
        return 'assets/images/icon_software.svg';
      case 'video':
        return 'assets/images/icon_video.svg';
      default:
        return 'assets/images/no_thumbnail.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final double dynamicPadding = math.min(
          LayoutConstants.space3,
          side * 0.03,
        );
        final double iconSize = math.min(
          LayoutConstants.iconSizeLarge,
          side * 0.3,
        );

        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: EdgeInsets.all(dynamicPadding),
            color: AppColor.auGreyBackground,
            child: Stack(
              children: [
                if (iconSize > 0)
                  Center(
                    child: SvgPicture.asset(
                      _getAssetDefault(),
                      width: iconSize,
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      alignment: AlignmentDirectional.bottomStart,
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'No thumbnail',
                        style: AppTypography.verySmall(context).bold.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
