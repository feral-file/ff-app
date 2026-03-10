import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/device_config_screen.dart';
import 'package:app/ui/screens/scan_qr_page.dart';
import 'package:app/ui/screens/tabs/channels_tab_page.dart';
import 'package:app/ui/screens/tabs/playlists_tab_page.dart';
import 'package:app/ui/screens/tabs/search_tab_page.dart';
import 'package:app/ui/screens/tabs/works_tab_page.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/bottom_spacing.dart';
import 'package:app/widgets/home_index_header.dart';
import 'package:app/widgets/no_pairing_device_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

// Global keys for each page to preserve state
final GlobalKey<PlaylistsTabPageState> _playlistsPageKey =
    GlobalKey<PlaylistsTabPageState>();
final GlobalKey<ChannelsTabPageState> _channelsPageKey =
    GlobalKey<ChannelsTabPageState>();
final GlobalKey<WorksTabPageState> _worksPageKey =
    GlobalKey<WorksTabPageState>();

/// Main home screen with tabbed navigation.
/// Matches the old app design exactly: NestedScrollView with Stack + Offstage.
class HomeIndexPage extends ConsumerStatefulWidget {
  /// Creates a HomeIndexPage.
  const HomeIndexPage({super.key});

  @override
  ConsumerState<HomeIndexPage> createState() => _HomeIndexPageState();
}

class _HomeIndexPageState extends ConsumerState<HomeIndexPage> {
  late HomeIndexHeaderTab _selectedTab;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _selectedTab = HomeIndexHeaderTab.playlists;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollChange);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScrollChange)
      ..dispose();
    super.dispose();
  }

  void _onScrollChange() {
    // Delegate scroll events to current page's load more logic
    // Each page handles its own scroll internally
  }

  @override
  Widget build(BuildContext context) {
    final seedState = ref.watch(seedDownloadProvider);
    final isScrollEnabled =
        seedState.status != SeedDownloadStatus.syncing &&
        seedState.status != SeedDownloadStatus.error;

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      body: NestedScrollView(
        controller: _scrollController,
        floatHeaderSlivers: true,
        physics: isScrollEnabled
            ? null
            : const NeverScrollableScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          final height = LayoutConstants.minTouchTarget;

          // Search button - navigates to search screen
          final searchButton = GestureDetector(
            onTap: () {
              unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const SearchTabPage(),
                  ),
                ),
              );
            },
            child: Container(
              color: Colors.transparent,
              width: LayoutConstants.minTouchTarget,
              height: LayoutConstants.minTouchTarget,
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/search.svg',
                  width: LayoutConstants.iconSizeMedium,
                  height: LayoutConstants.iconSizeMedium,
                  colorFilter: const ColorFilter.mode(
                    AppColor.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          );

          // Hamburger menu button
          final hamburgerButton = GestureDetector(
            onTap: () {
              _showMenu(context);
            },
            child: Container(
              color: Colors.transparent,
              width: LayoutConstants.minTouchTarget,
              height: LayoutConstants.minTouchTarget,
              child: Center(
                child: SvgPicture.asset(
                  'assets/images/Drawer.svg',
                  width: LayoutConstants.iconSizeMedium,
                  height: LayoutConstants.iconSizeMedium,
                  colorFilter: const ColorFilter.mode(
                    AppColor.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          );

          return [
            SliverAppBar(
              floating: true,
              snap: true,
              elevation: 0,
              toolbarHeight: height,
              expandedHeight: height,
              flexibleSpace: FlexibleSpaceBar(
                background: ColoredBox(
                  color: AppColor.auGreyBackground,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: LayoutConstants.space4,
                              ),
                              child: HomeIndexHeader(
                                selectedTab: _selectedTab,
                                onTabChanged: (tab) {
                                  setState(() {
                                    _selectedTab = tab;
                                  });
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: LayoutConstants.space3),
                          if (isScrollEnabled) searchButton,
                          hamburgerButton,
                          SizedBox(width: LayoutConstants.space3),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: CustomScrollView(
          physics: isScrollEnabled
              ? null
              : const NeverScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(height: LayoutConstants.space10),
            ),
            SliverToBoxAdapter(
              child: _buildContent(),
            ),
            const SliverToBoxAdapter(child: BottomSpacing()),
          ],
        ),
      ),
    );
  }

  List<OptionItem> get _defaultOptions {
    return [
      // Scan option for debug only
      if (kDebugMode)
        OptionItem(
          title: 'Scan',
          icon: const Icon(
            Icons.qr_code_scanner,
            color: AppColor.white,
          ),
          onTap: () {
            Navigator.of(context).pop();
            unawaited(
              context.push(
                Routes.scanQrPage,
                extra: const ScanQrPagePayload(),
              ),
            );
          },
        ),
      // FF1 Setting
      OptionItem(
        title: 'FF1 Art Computer',
        icon: SvgPicture.asset(
          'assets/images/portal_setting.svg',
          width: LayoutConstants.iconSizeMedium,
          height: LayoutConstants.iconSizeMedium,
          colorFilter: const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
        ),
        onTap: () {
          Navigator.of(context).pop();
          final isPaired =
              ref.read(activeFF1BluetoothDeviceProvider).value != null;
          if (!isPaired) {
            unawaited(_showNoPairingDialog());
            return;
          }

          unawaited(
            context.push(
              Routes.deviceConfiguration,
              extra: DeviceConfigPayload(isInSetupProcess: false),
            ),
          );
        },
      ),
      // Personal Preferences & Data, Security Management
      OptionItem(
        title: 'Account',
        icon: SvgPicture.asset(
          'assets/images/icon_account.svg',
          width: LayoutConstants.iconSizeMedium,
          height: LayoutConstants.iconSizeMedium,
          colorFilter: const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
        ),
        onTap: () {
          Navigator.of(context).pop();
          unawaited(context.push(Routes.settings));
        },
      ),
      // Support & Feedback
      OptionItem(
        title: 'Support & Feedback',
        icon: ValueListenableBuilder<List<int>?>(
          valueListenable: ValueNotifier<List<int>?>(null),
          builder:
              (
                context,
                numberOfIssuesInfo,
                child,
              ) => const Icon(
                Icons.help_outline,
                color: AppColor.white,
              ),
        ),
        onTap: () async {
          Navigator.pop(context);
          await _contactSupport();
        },
      ),
      // Release Notes
      OptionItem(
        title: 'Release Notes',
        icon: SvgPicture.asset(
          'assets/images/info.svg',
          width: 22,
          height: 22,
          colorFilter: const ColorFilter.mode(AppColor.white, BlendMode.srcIn),
        ),
        onTap: () {
          Navigator.of(context).pop();
          unawaited(context.push(Routes.releaseNotes));
        },
      ),
    ];
  }

  Widget _addAddressButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(context).pop();
        unawaited(context.push(Routes.addAddressPage));
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        side: const BorderSide(color: PrimitivesTokens.colorsLightBlue),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/images/icon_account.svg',
            width: LayoutConstants.iconSizeDefault,
            height: LayoutConstants.iconSizeDefault,
            colorFilter: const ColorFilter.mode(
              PrimitivesTokens.colorsLightBlue,
              BlendMode.srcIn,
            ),
          ),
          SizedBox(width: LayoutConstants.space2),
          Text(
            'Add Address',
            style: AppTypography.body(context).copyWith(
              color: PrimitivesTokens.colorsLightBlue,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNoPairingDialog() async {
    const screenKey = 'No pairing';
    if (UIHelper.currentDialogTitle == screenKey) {
      return;
    }

    UIHelper.currentDialogTitle = screenKey;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      builder: (context) => const NoPairingDeviceDialog(),
    );

    UIHelper.currentDialogTitle = '';
  }

  void _showMenu(BuildContext context) {
    unawaited(
      UIHelper.showCenterMenu(
        context,
        options: _defaultOptions,
        bottomWidget: _addAddressButton(),
      ),
    );
  }

  Future<void> _contactSupport() async {
    try {
      await ref.read(supportEmailServiceProvider).composeSupportEmail(
            recipient: 'support@feralfile.com',
          );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email client.'),
        ),
      );
    }
  }

  Widget _buildContent() {
    // Use Stack with Offstage instead of IndexedStack (matches old app).
    // Offstage keeps widgets alive (not disposed) while hiding them.
    // Each page can determine its own height independently.
    return Stack(
      children: [
        Offstage(
          offstage: _selectedTab != HomeIndexHeaderTab.playlists,
          child: PlaylistsTabPage(
            key: _playlistsPageKey,
            isActive: _selectedTab == HomeIndexHeaderTab.playlists,
          ),
        ),
        Offstage(
          offstage: _selectedTab != HomeIndexHeaderTab.channels,
          child: ChannelsTabPage(
            key: _channelsPageKey,
            isActive: _selectedTab == HomeIndexHeaderTab.channels,
          ),
        ),
        Offstage(
          offstage: _selectedTab != HomeIndexHeaderTab.works,
          child: WorksTabPage(
            key: _worksPageKey,
            isActive: _selectedTab == HomeIndexHeaderTab.works,
          ),
        ),
      ],
    );
  }
}
