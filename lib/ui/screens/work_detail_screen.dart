import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:app/app/providers/me_section_playlists_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/providers/works_provider.dart';
import 'package:app/app/utils/html/au_html_style.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/domain/extensions/asset_token_ext.dart';
import 'package:app/domain/extensions/playlist_ext.dart';
import 'package:app/domain/models/dp1/dp1_intent.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/indexer/asset_token.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/converters.dart' show DatabaseConverters;
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/work_detail_back_layer.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:app/widgets/bottom_spacing.dart';
import 'package:app/widgets/buttons/outline_button.dart';
import 'package:app/widgets/delayed_loading.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/ff_display_button.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/webview_controller_text_field.dart';
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
    with AfterLayoutMixin<WorkDetailScreen>, SingleTickerProviderStateMixin {
  static const double _infoShrinkPosition = 0.001;
  static const double _infoExpandPosition = 0.29;

  /// Matches old repo artwork_detail_page _infoHeaderHeight for bottom spacer.
  static const double _infoHeaderHeight = 68;

  late AnimationController _animationController;
  bool _isInfoExpand = false;
  double? _appBarBottomDy;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _selectTextFocusNode = FocusNode();

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
    _infoShrink();
  }

  @override
  void afterFirstLayout(BuildContext context) {
    const appBarHeight = kToolbarHeight + 20;
    _appBarBottomDy ??= appBarHeight + MediaQuery.of(context).padding.top;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.dispose();
    _textController.dispose();
    _selectTextFocusNode.dispose();
    super.dispose();
  }

  void _infoShrink() {
    setState(() {
      _isInfoExpand = false;
    });
    _selectTextFocusNode.unfocus();
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
        appBar: MainAppBar.preferred(
          context,
          backTitle: widget.backTitle ?? 'Work',
          backgroundColor: AppColor.auGreyBackground,
        ),
        body: const DelayedLoadingGate(
          isLoading: true,
          child: LoadingView(),
        ),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        appBar: MainAppBar.preferred(
          context,
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
            appBar: MainAppBar.preferred(
              context,
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

        final item = data.item;
        final artistStr = artistStringFromPlaylistItem(item);

        return Scaffold(
          backgroundColor: AppColor.auGreyBackground,
          body: Stack(
            children: [
              BackdropScaffold(
                backgroundColor: AppColor.auGreyBackground,
                resizeToAvoidBottomInset: false,
                appBar: MainAppBar.preferred(
                  context,
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
                    child: Container(
                      child: _buildSubHeader(
                        context,
                        data,
                        item,
                        artistStr,
                      ),
                    ),
                  ),
                ),
              ),
              if (_isInfoExpand)
                Positioned(
                  top: _appBarBottomDy ?? 80,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _infoShrink,
                    onVerticalDragEnd: (details) {
                      final dy = details.primaryVelocity ?? 0;
                      if (dy > 0) {
                        _infoShrink();
                      }
                    },
                    child: Container(
                      color: Colors.transparent,
                      height:
                          (MediaQuery.of(context).size.height -
                              (_appBarBottomDy ?? 80) -
                              _infoHeaderHeight) *
                          0.5,
                      width: MediaQuery.of(context).size.width,
                    ),
                  ),
                ),
            ],
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
    var subTitle = '';
    if (artistStr.isNotEmpty) {
      subTitle = artistStr;
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
          child: Row(
            children: [
              Expanded(
                child: ArtworkDetailsHeader(
                  title: item.title ?? '',
                  subTitle: subTitle,
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
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppColor.white,
                  ),
                )
              else ...[
                Consumer(
                  builder: (context, ref, _) {
                    final isFavorite =
                        ref.watch(isWorkInFavoriteProvider(item.id));
                    return IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        await ref
                            .read(favoritePlaylistServiceProvider)
                            .toggleFavorite(item);
                      },
                      constraints: const BoxConstraints(
                        maxWidth: 44,
                        maxHeight: 44,
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      icon: isFavorite.when(
                        data: (isIn) => SvgPicture.asset(
                          isIn
                              ? 'assets/images/select_circle_white.svg'
                              : 'assets/images/add_circle_white.svg',
                          width: 22,
                          height: 22,
                        ),
                        loading: () => SvgPicture.asset(
                          'assets/images/add_circle_white.svg',
                          width: 22,
                          height: 22,
                        ),
                        error: (_, _) => SvgPicture.asset(
                          'assets/images/add_circle_white.svg',
                          width: 22,
                          height: 22,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showArtworkOptionsDialog(
                    context,
                    item,
                    data.token,
                  ),
                  constraints: const BoxConstraints(
                    maxWidth: 44,
                    maxHeight: 44,
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: SvgPicture.asset(
                    'assets/images/more_circle.svg',
                    width: 22,
                    height: 22,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!_isInfoExpand)
          const BottomSpacing(checkNowDisplayingVisibility: false),
      ],
    );
  }

  Future<void> _showArtworkOptionsDialog(
    BuildContext context,
    PlaylistItem item,
    AssetToken? token,
  ) async {
    if (!context.mounted) return;
    _focusNode.unfocus();

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
          final cid = item.cid;
          if (cid == null || cid.isEmpty) {
            if (context.mounted) {
              await UIHelper.showDialog<void>(
                context,
                'Rebuild metadata',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'This work has no token to rebuild metadata for',
                      style: AppTypography.body(context).white,
                    ),
                    const SizedBox(height: 24),
                    OutlineButton(
                      text: 'OK',
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            }
            return;
          }
          try {
            await ref
                .read(workDetailStateProvider(widget.workId).notifier)
                .rebuildMetadata(item);
            if (context.mounted) {
              await UIHelper.showDialog<void>(
                context,
                'Metadata rebuilt',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'The work metadata has been refreshed.',
                      style: AppTypography.body(context).white,
                    ),
                    const SizedBox(height: 24),
                    OutlineButton(
                      text: 'OK',
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              await UIHelper.showDialog<void>(
                context,
                'Rebuild metadata',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rebuild metadata is incomplete. Try again later '
                      'or contact support for help.',
                      style: AppTypography.body(context).white,
                    ),
                    const SizedBox(height: 24),
                    OutlineButton(
                      text: 'Retry later',
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 12),
                    OutlineButton(
                      text: 'Contact support',
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(
                          UIHelper.showCustomerSupport(
                            context,
                            supportEmailService: ref.read(
                              supportEmailServiceProvider,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }
          }
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

    return Stack(
      children: [
        Visibility(
          child: WebviewControllerTextField(
            focusNode: _focusNode,
            textController: _textController,
          ),
        ),
        NotificationListener<UserScrollNotification>(
          onNotification: (_) => true,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Visibility(
                    visible: false,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 20,
                      ),
                      child: OutlineButton(
                        color: Colors.transparent,
                        text: '',
                        onTap: () {},
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: 'Desc',
                          child: SelectionArea(
                            focusNode: _selectTextFocusNode,
                            child: HtmlWidget(
                              descriptionHtml,
                              customStylesBuilder: auHtmlStyle,
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
                        ),
                        const SizedBox(height: 40),
                        buildWorkDetailMetadataSection(
                          context,
                          item: item,
                          token: token,
                        ),
                        if (token != null)
                          ownerAddressesAsync.when(
                            data: (addresses) =>
                                buildWorkDetailTokenOwnershipSection(
                                  context,
                                  ownerAddresses: addresses,
                                  token: token,
                                ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        if (token != null)
                          ownerAddressesAsync.when(
                            data: (addresses) =>
                                buildWorkDetailProvenanceSection(
                                  context,
                                  ownerAddresses: addresses,
                                  token: token,
                                ),
                            loading: () => const SizedBox.shrink(),
                            error: (_, _) => const SizedBox.shrink(),
                          ),
                        buildWorkDetailRightSection(context, item, token),
                        const SizedBox(height: 80),
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
                  if (_isInfoExpand)
                    const BottomSpacing(checkNowDisplayingVisibility: false),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
