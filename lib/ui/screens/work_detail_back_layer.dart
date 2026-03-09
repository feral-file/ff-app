// ignore_for_file: dead_code
// Copied from old repo ArtworkBackLayer + ArtworkPreviewWidget + NoPreviewWidget + PreviewPlaceholder.
// Data source: PlaylistItem + nullable mimeType; preview URL and thumbnail from item.
// Preview rendering uses NFT rendering widgets from lib/nft_rendering/.

import 'dart:math';

import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/playlist_item_ext.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/nft_rendering/audio_rendering_widget.dart';
import 'package:app/nft_rendering/gif_rendering_widget.dart';
import 'package:app/nft_rendering/image_rendering_widget.dart';
import 'package:app/nft_rendering/pdf_rendering_widget.dart';
import 'package:app/nft_rendering/svg_rendering_widget.dart';
import 'package:app/nft_rendering/video_player_widget.dart';
import 'package:app/nft_rendering/webview_rendering_widget.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/bottom_spacing.dart';
import 'package:app/widgets/delayed_loading.dart';
import 'package:app/widgets/gallery_thumbnail_widgets.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/work_detail/artwork_details_header.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Back layer for work detail. Structure copied from old repo [ArtworkBackLayer];
/// only renamed and data from [PlaylistItem].
class WorkDetailBackLayer extends StatelessWidget {
  const WorkDetailBackLayer({
    required this.item,
    required this.isFullScreen,
    super.key,
    this.onLoaded,
    this.mimeType,
  });

  final PlaylistItem item;
  final bool isFullScreen;
  final String? mimeType;
  final void Function({Object? webViewController, int? time})? onLoaded;

  @override
  Widget build(BuildContext context) {
    const isPlayingOnFF1 = false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 45),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal:
                      LayoutConstants.dp1CarouselContentPaddingHorizontal,
                ),
                child: Center(
                  child: isPlayingOnFF1
                      ? WorkDetailThumbnailView(item: item)
                      : WorkPreviewWidget(
                          item: item,
                          mimeType: mimeType,
                          onLoaded: onLoaded,
                        ),
                ),
              ),
              if (isPlayingOnFF1)
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: AppColor.primaryBlack.withValues(alpha: 0.2),
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    child: const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 45),
        if (!isFullScreen)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const ArtworkDetailsHeader(
                  title: 'I',
                  subTitle: 'I',
                  color: Colors.transparent,
                ),
              ),
              const BottomSpacing(),
            ],
          ),
      ],
    );
  }
}

/// Copied from old repo [ArtworkThumbnailView]; data from [PlaylistItem].
class WorkDetailThumbnailView extends StatelessWidget {
  const WorkDetailThumbnailView({required this.item, super.key});

  final PlaylistItem item;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = item.thumbnailUrl;
    return Opacity(
      opacity: 0.5,
      child: (thumbnailUrl != null && thumbnailUrl.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: thumbnailUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) =>
                  const GalleryThumbnailPlaceholder(),
              errorWidget: (context, url, error) =>
                  const GalleryThumbnailErrorWidget(),
            )
          : const GalleryNoThumbnailWidget(),
    );
  }
}

/// Copied from old repo [PreviewPlaceholder]. Exact same behavior.
Widget previewPlaceholder() => const PreviewPlaceholder();

class PreviewPlaceholder extends StatefulWidget {
  const PreviewPlaceholder({super.key});

  @override
  State<PreviewPlaceholder> createState() => _PreviewPlaceholderState();
}

class _PreviewPlaceholderState extends State<PreviewPlaceholder> {
  @override
  Widget build(BuildContext context) => const DelayedLoadingGate(
    isLoading: true,
    child: LoadingView(),
  );
}

/// Copied from old repo [NoPreviewWidget]. Exact same structure.
class NoPreviewWidget extends StatelessWidget {
  const NoPreviewWidget({this.mimeType, super.key});

  final String? mimeType;

  String getAssetDefault() {
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
        final dynamicPadding = min(
          LayoutConstants.space3,
          side * 0.03,
        );
        final iconSize = min(
          LayoutConstants.iconSizeLarge,
          side * 0.3,
        );

        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: EdgeInsets.all(dynamicPadding),
            color: AppColor.auLightGrey,
            child: iconSize > 0
                ? Center(
                    child: SvgPicture.asset(
                      getAssetDefault(),
                      width: iconSize,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}

/// Copied from old repo [ArtworkPreviewWidget]. Build structure and switch unchanged;
/// data source: item (preview URL, thumbnail) + mimeType from parent.
class WorkPreviewWidget extends StatefulWidget {
  const WorkPreviewWidget({
    required this.item,
    super.key,
    this.onLoaded,
    this.mimeType,
  });

  final PlaylistItem item;
  final String? mimeType;
  final void Function({Object? webViewController, int? time})? onLoaded;

  @override
  State<WorkPreviewWidget> createState() => _WorkPreviewWidgetState();
}

class _WorkPreviewWidgetState extends State<WorkPreviewWidget> {
  Widget? _currentRenderingWidget;

  @override
  void didUpdateWidget(covariant WorkPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mimeType != widget.mimeType ||
        oldWidget.item != widget.item) {
      _currentRenderingWidget = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewURL = widget.item.sourceUrl ?? '';

    if (previewURL.isEmpty) {
      return previewPlaceholder();
    }

    final resolvedMimeType = widget.mimeType ?? 'webview';

    return Builder(
      builder: (context) {
        switch (resolvedMimeType) {
          case 'image':
            _currentRenderingWidget = ImageNFTRenderingWidget(
              previewURL: previewURL,
            );
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: _currentRenderingWidget,
              ),
            );
          case 'video':
            _currentRenderingWidget = VideoNFTRenderingWidget(
              previewURL: previewURL,
              thumbnailURL: widget.item.thumbnailUrl,
            );
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: _currentRenderingWidget,
              ),
            );
          case 'gif':
            _currentRenderingWidget = GifNFTRenderingWidget(
              previewURL: previewURL,
            );
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: _currentRenderingWidget,
              ),
            );
          case 'svg':
            _currentRenderingWidget = SVGNFTRenderingWidget(
              previewURL: previewURL,
            );
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: _currentRenderingWidget,
              ),
            );
          case 'application/pdf':
            _currentRenderingWidget = PDFNFTRenderingWidget(
              previewURL: previewURL,
            );
            return Center(
              child: _currentRenderingWidget,
            );
          case 'audio':
            _currentRenderingWidget = AudioNFTRenderingWidget(
              previewURL: previewURL,
              thumbnailURL: widget.item.thumbnailUrl,
            );
            return Center(
              child: _currentRenderingWidget,
            );
          default:
            _currentRenderingWidget = WebviewNFTRenderingWidget(
              previewUri: Uri.parse(previewURL),
            );
            return Center(
              child: _currentRenderingWidget,
            );
        }
      },
    );
  }
}
