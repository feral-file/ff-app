import 'package:app/app/routing/routes.dart';
import 'package:app/ui/screens/channel_detail_screen.dart';
import 'package:app/ui/screens/channels_screen.dart';
import 'package:app/ui/screens/home_screen.dart';
import 'package:app/ui/screens/playlist_detail_screen.dart';
import 'package:app/ui/screens/work_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Master router provider using go_router.
/// This is the single source of truth for navigation in the app.
/// All navigation state flows through Riverpod.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: Routes.home,
    routes: [
      GoRoute(
        path: Routes.home,
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.channels,
        name: RouteNames.channels,
        builder: (context, state) => const ChannelsScreen(),
        routes: [
          GoRoute(
            path: ':channelId',
            name: RouteNames.channelDetail,
            builder: (context, state) {
              final channelId = state.pathParameters['channelId']!;
              return ChannelDetailScreen(channelId: channelId);
            },
          ),
        ],
      ),
      GoRoute(
        path: Routes.playlists,
        name: RouteNames.playlists,
        builder: (context, state) {
          // Placeholder - can be replaced with PlaylistsScreen
          return const Scaffold(
            body: Center(child: Text('Playlists')),
          );
        },
        routes: [
          GoRoute(
            path: ':playlistId',
            name: RouteNames.playlistDetail,
            builder: (context, state) {
              final playlistId = state.pathParameters['playlistId']!;
              return PlaylistDetailScreen(playlistId: playlistId);
            },
          ),
        ],
      ),
      GoRoute(
        path: Routes.works,
        name: RouteNames.works,
        builder: (context, state) {
          // Placeholder - can be replaced with WorksScreen
          return const Scaffold(
            body: Center(child: Text('Works')),
          );
        },
        routes: [
          GoRoute(
            path: ':workId',
            name: RouteNames.workDetail,
            builder: (context, state) {
              final workId = state.pathParameters['workId']!;
              return WorkDetailScreen(workId: workId);
            },
          ),
        ],
      ),
    ],
  );
});
