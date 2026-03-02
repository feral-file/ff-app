import 'dart:async';

import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/providers/works_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/asset_token_ext.dart';
import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/dp1/dp1_intent.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/converters.dart' show DatabaseConverters;
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/work_detail_back_layer.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:app/widgets/bottom_spacing.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/ff_display_button.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/work_detail/artwork_details_header.dart';
import 'package:app/widgets/work_detail/work_detail_sections.dart';
import 'package:backdrop/backdrop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

/// Work detail screen.
/// Shows details for a playlist item (work). UI matches old artwork detail page:
/// BackdropScaffold with back layer (media), front layer (info panel), subheader.
/// Data: [PlaylistItem] always; [AssetToken] optional from indexer.
class WorkDetailScreen extends ConsumerStatefulWidget {
  const WorkDetailScreen({
    required this.workId,
    super.key,
    this.backTitle,
  });

  /// Playlist item ID (workId from route).
  final String workId;

  /// Optional back button label.
  final String? backTitle;

  @override
  ConsumerState<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends ConsumerState<WorkDetailScreen>
    with SingleTickerProviderStateMixin {
  static const double _infoShrinkPosition = 0.001;
  static const double _infoExpandPosition = 0.29;

  /// Matches old repo artwork_detail_page _infoHeaderHeight for bottom spacer.
  static const double _infoHeaderHeight = 68;

  late AnimationController _animationController;
  bool _isInfoExpand = false;
  double? _appBarBottomDy;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 300),
      value: _infoShrinkPosition,
      upperBound: _infoExpandPosition,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _infoShrink() {
    setState(() {
      _isInfoExpand = false;
    });
    _animationController.animateTo(_infoShrinkPosition);
  }

  void _infoExpand() {
    setState(() {
      _isInfoExpand = true;
    });
    _animationController.animateTo(_infoExpandPosition);
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(workDetailStateProvider(widget.workId));

    return asyncData.when(
      loading: () => Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        appBar: MainAppBar(
          backTitle: widget.backTitle ?? 'Work',
          backgroundColor: AppColor.auGreyBackground,
        ),
        body: const LoadingView(),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        appBar: MainAppBar(
          backTitle: widget.backTitle ?? 'Work',
          backgroundColor: AppColor.auGreyBackground,
        ),
        body: ErrorView(
          error:
              'We couldn’t load this work. Check your connection, then Retry.',
          onRetry: () => ref.invalidate(workDetailStateProvider(widget.workId)),
        ),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            backgroundColor: AppColor.auGreyBackground,
            appBar: MainAppBar(
              backTitle: widget.backTitle ?? 'Work',
              backgroundColor: AppColor.auGreyBackground,
            ),
            body: Center(
              child: Text(
                'Work not found',
                style: AppTypography.body(context).grey,
              ),
            ),
          );
        }

        _appBarBottomDy ??=
            kToolbarHeight +
            LayoutConstants.space5 +
            MediaQuery.of(context).padding.top;

        final item = data.item;
        final artistStr = artistStringFromPlaylistItem(item);

        return Scaffold(
          backgroundColor: AppColor.auGreyBackground,
          body: BackdropScaffold(
            backgroundColor: AppColor.auGreyBackground,
            frontLayerElevation: 1,
            appBar: MainAppBar(
              backTitle: widget.backTitle ?? 'Work',
              backgroundColor: AppColor.auGreyBackground,
              actions: [
                FFDisplayButton(
                  onDeviceSelected: (device) async {
                    final canvas = ref.read(canvasClientServiceV2Provider);
                    final items = [item];
                    final singleWorkPlaylist = PlaylistExt.fromPlaylistItem(
                      items,
                    );
                    final dp1 =
                        DatabaseConverters.playlistAndItemsToDP1Playlist(
                          singleWorkPlaylist,
                          items,
                        );
                    await canvas.castPlaylist(
                      device,
                      dp1,
                      DP1Intent.displayNow(),
                      usingUrl: false,
                    );
                  },
                ),
              ],
            ),
            backLayer: WorkDetailBackLayer(
              item: item,
              isFullScreen: false,
              mimeType: data.mimeType,
            ),
            reverseAnimationCurve: Curves.ease,
            frontLayer: _buildFrontLayer(context, data),
            frontLayerBackgroundColor: AppColor.auGreyBackground,
            backLayerBackgroundColor: AppColor.auGreyBackground,
            animationController: _animationController,
            revealBackLayerAtStart: true,
            frontLayerScrim: Colors.transparent,
            backLayerScrim: Colors.transparent,
            subHeaderAlwaysActive: false,
            frontLayerShape: const BeveledRectangleBorder(),
            // Expand is also triggered by package backdrop: see _buildInactiveLayer() in
            // backdrop/lib/src/scaffold.dart — a GestureDetector(onTap: () => fling())
            // overlays the front panel when back layer is revealed; tap on subHeader
            // area hits that overlay and calls fling() (expand). Our 3-dot uses a
            // GestureDetector to show options; the overlay is on top so it may still
            // win. Drag (onVerticalDragEnd below) is the other place we call _infoExpand.
            subHeader: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColor.auGreyBackground,
              ),
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  final dy = details.primaryVelocity ?? 0;
                  if (dy <= 0) {
                    _infoExpand();
                  } else {
                    _infoShrink();
                  }
                },
                child: _buildSubHeader(context, data, item, artistStr),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubHeader(
    BuildContext context,
    WorkDetailData data,
    PlaylistItem item,
    String artistStr,
  ) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            LayoutConstants.space3,
            LayoutConstants.space2,
            0,
            LayoutConstants.space2,
          ),
          child: Row(
            children: [
              Expanded(
                child: ArtworkDetailsHeader(
                  title: item.title ?? '',
                  subTitle: artistStr,
                ),
              ),
              if (_isInfoExpand)
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: _infoShrink,
                  constraints: const BoxConstraints(
                    maxWidth: 44,
                    maxHeight: 44,
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: Icon(
                    Icons.close,
                    size: LayoutConstants.iconSizeDefault,
                    color: AppColor.white,
                  ),
                )
              else
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showArtworkOptionsDialog(
                    context,
                    item,
                    data.token,
                  ),
                  child: SizedBox(
                    width: LayoutConstants.minTouchTarget,
                    height: LayoutConstants.minTouchTarget,
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/images/more_circle.svg',
                        width: 22,
                        height: 22,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (!_isInfoExpand) const BottomSpacing(),
      ],
    );
  }

  Future<void> _showArtworkOptionsDialog(
    BuildContext context,
    PlaylistItem item,
    AssetToken? token,
  ) async {
    if (!context.mounted) return;

    // Match old artwork_detail_page: same order, same icon sizes (pixel-exact).
    final options = <OptionItem>[
      OptionItem(
        title: 'Full screen',
        icon: SvgPicture.asset(
          'assets/images/fullscreen_icon.svg',
          width: 18,
          height: 18,
        ),
        onTap: () {
          Navigator.of(context).pop();
          // Full screen not implemented; matches old structure.
        },
      ),
      if (token != null && token.secondaryMarketURL.isNotEmpty)
        OptionItem(
          title: 'View on ${token.secondaryMarketName}',
          icon: SvgPicture.asset(
            'assets/images/external_link_white.svg',
            width: 20,
            height: 20,
          ),
          onTap: () async {
            Navigator.of(context).pop();
            await launchUrl(
              Uri.parse(token.secondaryMarketURL),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
      OptionItem(
        title: 'Artwork details',
        icon: SvgPicture.asset(
          'assets/images/info_white.svg',
          width: 22,
          height: 22,
        ),
        onTap: () {
          Navigator.of(context).pop();
          _infoExpand();
        },
      ),
      OptionItem(
        title: 'Rebuild metadata',
        icon: SvgPicture.asset(
          'assets/images/refresh_metadata_white.svg',
          width: 20,
          height: 20,
        ),
        onTap: () async {
          Navigator.of(context).pop();
          ref.invalidate(workDetailStateProvider(widget.workId));
        },
      ),
    ];

    unawaited(UIHelper.showCenterMenu(context, options: options));
  }

  Widget _buildFrontLayer(BuildContext context, WorkDetailData data) {
    final item = data.item;
    final token = data.token;
    final ownerAddressesAsync = ref.watch(ownerAddressesProvider);

    final descriptionHtml = token != null && token.displayDescription.isNotEmpty
        ? token.displayDescription
        : '';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: LayoutConstants.pageHorizontalDefault,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (descriptionHtml.isNotEmpty) ...[
                    SelectionArea(
                      child: HtmlWidget(
                        descriptionHtml,
                        textStyle: AppTypography.body(context).white,
                        onTapUrl: (url) async {
                          await launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          );
                          return true;
                        },
                      ),
                    ),
                    SizedBox(height: LayoutConstants.space10),
                  ],
                  buildWorkDetailMetadataSection(
                    context,
                    item: item,
                    token: token,
                  ),
                  if (token != null)
                    ownerAddressesAsync.when(
                      data: (addresses) => buildWorkDetailTokenOwnershipSection(
                        context,
                        ownerAddresses: addresses,
                        token: token,
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  if (token != null)
                    ownerAddressesAsync.when(
                      data: (addresses) => buildWorkDetailProvenanceSection(
                        context,
                        ownerAddresses: addresses,
                        token: token,
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  buildWorkDetailRightSection(context, item, token),
                  SizedBox(height: LayoutConstants.space20),
                ],
              ),
            ),
            SizedBox(
              height:
                  (MediaQuery.of(context).size.height -
                      (_appBarBottomDy ?? 80) -
                      _infoHeaderHeight) *
                  0.5,
            ),
          ],
        ),
      ),
    );
  }
}
