import 'package:app/app/routing/routes.dart';
import 'package:app/ui/screens/channel_detail_screen.dart';
import 'package:app/ui/screens/home_index_page.dart';
import 'package:app/ui/screens/playlist_detail_screen.dart';
import 'package:app/ui/screens/work_detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Master router provider using go_router.
/// This is the single source of truth for navigation in the app.
/// All navigation state flows through Riverpod.
/// 
/// Note: List views (channels, playlists, works) are now tabs in HomeIndexPage.
/// Only detail screens have dedicated routes.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: Routes.home,
    routes: [
      // Home route with tabs (playlists, channels, works, search)
      GoRoute(
        path: Routes.home,
        name: RouteNames.home,
        builder: (context, state) => const HomeIndexPage(),
      ),
      
      // Channel detail route
      GoRoute(
        path: '${Routes.channels}/:channelId',
        name: RouteNames.channelDetail,
        builder: (context, state) {
          final channelId = state.pathParameters['channelId']!;
          return ChannelDetailScreen(channelId: channelId);
        },
      ),
      
      // Playlist detail route
      GoRoute(
        path: '${Routes.playlists}/:playlistId',
        name: RouteNames.playlistDetail,
        builder: (context, state) {
          final playlistId = state.pathParameters['playlistId']!;
          return PlaylistDetailScreen(playlistId: playlistId);
        },
      ),
      
      // Work detail route
      GoRoute(
        path: '${Routes.works}/:workId',
        name: RouteNames.workDetail,
        builder: (context, state) {
          final workId = state.pathParameters['workId']!;
          return WorkDetailScreen(workId: workId);
        },
      ),
    ],
  );
});
