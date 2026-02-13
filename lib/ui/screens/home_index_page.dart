import 'package:app/app/providers/services_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/tabs/channels_tab_page.dart';
import 'package:app/ui/screens/tabs/playlists_tab_page.dart';
import 'package:app/ui/screens/tabs/search_tab_page.dart';
import 'package:app/ui/screens/tabs/works_tab_page.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/bottom_spacing.dart';
import 'package:app/widgets/home_index_header.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    _scrollController.removeListener(_onScrollChange);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollChange() {
    // Delegate scroll events to current page's load more logic
    // Each page handles its own scroll internally
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      body: NestedScrollView(
        controller: _scrollController,
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          final height = LayoutConstants.minTouchTarget;

          // Search button - navigates to search screen
          final searchButton = GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const SearchTabPage(),
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
              pinned: false,
              floating: true,
              snap: true,
              elevation: 0,
              toolbarHeight: height,
              expandedHeight: height,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
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
                          searchButton,
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
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: LayoutConstants.space10),
              _buildContent(),
              const BottomSpacing(),
            ],
          ),
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
        },
      ),
      // Support & Feedback
      OptionItem(
        title: 'Support & Feedback',
        icon: ValueListenableBuilder<List<int>?>(
          valueListenable: ValueNotifier<List<int>?>(null),
          builder:
              (
                BuildContext context,
                List<int>? numberOfIssuesInfo,
                Widget? child,
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
        },
      ),
    ];
  }

  Widget _addAddressButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.of(context).pop();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        side: BorderSide(color: PrimitivesTokens.colorsLightBlue),
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

  void _showMenu(BuildContext context) {
    UIHelper.showCenterMenu(
      context,
      options: _defaultOptions,
      bottomWidget: _addAddressButton(),
    );
  }

  Future<void> _contactSupport() async {
    try {
      await ref
          .read(supportEmailServiceProvider)
          .composeSupportEmail(recipient: 'support@feralfile.com');
    } on Exception {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email client.'),
        ),
      );
    }
  }

  Widget _buildContent() {
    // Use Stack with Offstage instead of IndexedStack (matches old app)
    // Offstage keeps widgets alive (not disposed) while hiding them
    // This allows each page to have independent constraints
    // Combined with AutomaticKeepAliveClientMixin in each page, state is preserved
    // Each page can determine its own height (limited or unlimited) independently
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
