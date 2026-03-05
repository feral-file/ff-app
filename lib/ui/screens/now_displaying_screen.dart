import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:app/widgets/common/touch_target.dart';
import 'package:app/widgets/gallery_thumbnail_widgets.dart';
import 'package:app/widgets/now_displaying_bar/now_displaying_quick_setting_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// Full-screen Now Displaying page.
///
/// UI copied exactly from old repo (now_displaying_page.dart).
/// Data from [nowDisplayingProvider]. Interact opens keyboard control.
/// More button opens FF1 Settings (Rotate/Fit/Fill) dialog.
class NowDisplayingScreen extends ConsumerWidget {
  const NowDisplayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(nowDisplayingProvider);

    final showMoreIcon = status is NowDisplayingSuccess;

    return Scaffold(
      appBar: MainAppBar(
        centeredTitle: 'Now playing',
        backgroundColor: AppColor.auGreyBackground,
        actions: showMoreIcon
            ? [
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _onMorePressed(context, status),
                  constraints: BoxConstraints(
                    minWidth: LayoutConstants.minTouchTarget,
                    minHeight: LayoutConstants.minTouchTarget,
                    maxWidth: LayoutConstants.minTouchTarget,
                    maxHeight: LayoutConstants.minTouchTarget,
                  ),
                  icon: TouchTarget(
                    minSize: LayoutConstants.minTouchTarget,
                    child: SvgPicture.asset(
                      'assets/images/more_circle.svg',
                      width: LayoutConstants.iconSizeMedium,
                      height: LayoutConstants.iconSizeMedium,
                    ),
                  ),
                ),
              ]
            : const [],
      ),
      backgroundColor: AppColor.auGreyBackground,
      body: _Body(status: status),
    );
  }
}

/// Opens FF1 Settings (Rotate/Fit/Fill) when a device is casting;
/// otherwise shows a message that user should pair an FF1.
void _onMorePressed(BuildContext context, NowDisplayingStatus status) {
  if (status is NowDisplayingSuccess &&
      status.object is DP1NowDisplayingObject) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PrimitivesTokens.colorsBlack,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LayoutConstants.space4),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(LayoutConstants.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'FF1 Settings',
                style: AppTypography.h4(context).white,
              ),
              SizedBox(height: LayoutConstants.space4),
              const NowDisplayingQuickSettingView(),
            ],
          ),
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pair an FF1 to adjust display settings',
          style: AppTypography.body(context).white,
        ),
        backgroundColor: PrimitivesTokens.colorsDarkGrey,
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.status});

  final NowDisplayingStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (status is InitialNowDisplayingStatus ||
        status is LoadingNowDisplaying) {
      return const Center(
        child: CircularProgressIndicator(color: AppColor.white),
      );
    }

    if (status is NoDevicePaired) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: LayoutConstants.pageHorizontalDefault,
          ),
          child: Text(
            'Pair an FF1 to start playing from any screen',
            style: AppTypography.body(context).white,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (status is DeviceDisconnected) {
      final device = (status as DeviceDisconnected).device;
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: LayoutConstants.pageHorizontalDefault,
        ),
        child: Text(
          '${device.name} disconnected',
          style: AppTypography.body(context).white,
        ),
      );
    }

    if (status is NowDisplayingError) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: LayoutConstants.pageHorizontalDefault,
          ),
          child: Text(
            "We couldn't load now displaying",
            style: AppTypography.body(context).white,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (status is NowDisplayingSuccess) {
      final object = (status as NowDisplayingSuccess).object;
      if (object is! DP1NowDisplayingObject) {
        return const SizedBox.shrink();
      }
      return _DP1NowDisplayingContent(object: object);
    }

    return const SizedBox.shrink();
  }
}

/// Content matching old repo DP1NowDisplaying: CustomScrollView with same
/// sliver order — 12px bar, token preview (thumbnail + divider + Interact),
/// info header, spacing, bottom padding. No Rotate/Fit/Fill on this page.
class _DP1NowDisplayingContent extends StatelessWidget {
  const _DP1NowDisplayingContent({required this.object});

  final DP1NowDisplayingObject object;

  @override
  Widget build(BuildContext context) {
    final item = object.currentItem;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            height: LayoutConstants.space3,
            color: PrimitivesTokens.colorsDarkGrey,
          ),
        ),
        SliverToBoxAdapter(
          child: _TokenPreview(item: item),
        ),
        SliverToBoxAdapter(
          child: _InfoHeader(
            title: item.title ?? '',
            subTitle: item.subtitle ?? '',
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space4),
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: LayoutConstants.space4),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: LayoutConstants.space20 + LayoutConstants.space5,
            ),
            child: const SizedBox(),
          ),
        ),
      ],
    );
  }
}

/// Matches old _tokenPreview: ColoredBox > Column(thumbnail 4:5, Divider,
/// Container padding 16 + Interact button only).
class _TokenPreview extends StatelessWidget {
  const _TokenPreview({required this.item});

  final PlaylistItem item;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PrimitivesTokens.colorsDarkGrey,
      child: Column(
        children: [
          Container(
            child: item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty
                ? AspectRatio(
                    aspectRatio: 4 / 5,
                    child: CachedNetworkImage(
                      imageUrl: item.thumbnailUrl!,
                      fit: BoxFit.contain,
                      placeholder: (_, _) =>
                          const GalleryThumbnailPlaceholder(),
                      errorWidget: (_, _, _) =>
                          const GalleryThumbnailErrorWidget(),
                    ),
                  )
                : const AspectRatio(
                    aspectRatio: 4 / 5,
                    child: GalleryNoThumbnailWidget(),
                  ),
          ),
          const Divider(
            color: AppColor.primaryBlack,
            height: 1,
          ),
          Container(
            padding: EdgeInsets.all(LayoutConstants.space4),
            child: _InteractButton(),
          ),
        ],
      ),
    );
  }
}

/// Matches old infoHeader: Padding fromLTRB(16, 16, 16, 20) and
/// ArtworkDetailsHeader layout (subTitle italic, then title bold).
class _InfoHeader extends StatelessWidget {
  const _InfoHeader({
    required this.title,
    required this.subTitle,
  });

  final String title;
  final String subTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        LayoutConstants.space4,
        LayoutConstants.space4,
        LayoutConstants.space4,
        LayoutConstants.space5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subTitle.isNotEmpty)
                  Text(
                    subTitle,
                    style: AppTypography.body(context).white.italic,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (subTitle.isNotEmpty)
                  SizedBox(height: LayoutConstants.space1),
                Text(
                  title,
                  style: AppTypography.body(context).white.bold,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Interact button: matches old PrimaryButton(color: white, text: Interact).
class _InteractButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.push(Routes.keyboardControl),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColor.white,
          foregroundColor: AppColor.primaryBlack,
          padding: EdgeInsets.symmetric(vertical: LayoutConstants.space3 + 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LayoutConstants.space8),
          ),
          elevation: 0,
        ),
        child: Text(
          'Interact',
          style: AppTypography.body(context).black,
        ),
      ),
    );
  }
}
