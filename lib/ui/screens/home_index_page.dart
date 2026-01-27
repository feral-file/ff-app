import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/tabs/channels_tab_page.dart';
import 'package:app/ui/screens/tabs/playlists_tab_page.dart';
import 'package:app/ui/screens/tabs/search_tab_page.dart';
import 'package:app/ui/screens/tabs/works_tab_page.dart';
import 'package:app/widgets/bottom_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Available tabs in the home screen.
enum HomeIndexTab {
  /// Playlists tab.
  playlists('Playlists'),

  /// Channels tab.
  channels('Channels'),

  /// Works tab.
  works('Works');

  /// Tab label.
  final String label;

  const HomeIndexTab(this.label);
}

// Global keys for each page to preserve state
final GlobalKey<PlaylistsTabPageState> _playlistsPageKey =
    GlobalKey<PlaylistsTabPageState>();
final GlobalKey<ChannelsTabPageState> _channelsPageKey =
    GlobalKey<ChannelsTabPageState>();
final GlobalKey<WorksTabPageState> _worksPageKey = GlobalKey<WorksTabPageState>();

/// Main home screen with tabbed navigation.
/// Matches the old app design exactly: NestedScrollView with Stack + Offstage.
class HomeIndexPage extends ConsumerStatefulWidget {
  /// Creates a HomeIndexPage.
  const HomeIndexPage({super.key});

  @override
  ConsumerState<HomeIndexPage> createState() => _HomeIndexPageState();
}

class _HomeIndexPageState extends ConsumerState<HomeIndexPage> {
  late HomeIndexTab _selectedTab;
  final TransformationController _transformationController =
      TransformationController();
  late ScrollController _scrollController;
  late final PlaylistsTabPage _playlistsPage;
  late final ChannelsTabPage _channelsPage;
  late final WorksTabPage _worksPage;

  @override
  void initState() {
    super.initState();
    _selectedTab = HomeIndexTab.playlists;
    _scrollController = ScrollController();
    _scrollController.addListener(_onScrollChange);
    _playlistsPage = PlaylistsTabPage(key: _playlistsPageKey);
    _channelsPage = ChannelsTabPage(key: _channelsPageKey);
    _worksPage = WorksTabPage(key: _worksPageKey);

    // Trigger bootstrap to fetch channels and playlists
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(bootstrapProvider.notifier).bootstrap();
      // Reload channels and playlists after bootstrap completes
      ref.read(channelsProvider.notifier).loadChannels();
      ref.read(playlistsProvider.notifier).loadPlaylists();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChange);
    _scrollController.dispose();
    _transformationController.dispose();
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
          const height = 43.5;
          
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
                child: Icon(
                  Icons.search,
                  size: LayoutConstants.iconSizeMedium,
                  color: AppColor.white,
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
                child: Icon(
                  Icons.menu,
                  size: LayoutConstants.iconSizeMedium,
                  color: AppColor.white,
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
                              padding: const EdgeInsets.only(top: 15),
                              child: _buildHomeIndexHeader(),
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
              const SizedBox(height: 37),
              _buildContent(),
              const BottomSpacing(),
            ],
          ),
        ),
      ),
    );
  }

  /// Home Index Header - Tab navigation matching old app design.
  Widget _buildHomeIndexHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: HomeIndexTab.values.map((tab) {
          final isSelected = tab == _selectedTab;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedTab = tab;
            }),
            child: Padding(
              padding: const EdgeInsets.only(right: 11),
              child: Text(
                tab.label,
                style: isSelected
                    ? AppTypography.body(context).white
                    : AppTypography.body(context).grey,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColor.primaryBlack,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.settings, color: AppColor.white),
                title: Text(
                  'Settings',
                  style: AppTypography.body(context).white,
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.info, color: AppColor.white),
                title: Text(
                  'About',
                  style: AppTypography.body(context).white,
                ),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
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
          offstage: _selectedTab != HomeIndexTab.playlists,
          child: _playlistsPage,
        ),
        Offstage(
          offstage: _selectedTab != HomeIndexTab.channels,
          child: _channelsPage,
        ),
        Offstage(
          offstage: _selectedTab != HomeIndexTab.works,
          child: _worksPage,
        ),
      ],
    );
  }
}
