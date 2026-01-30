import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/ui/screens/channel_detail_screen.dart';
import 'package:app/ui/screens/connected_devices_screen.dart';
import 'package:app/ui/screens/ff1_test_screen.dart';
import 'package:app/ui/screens/home_index_page.dart';
import 'package:app/ui/screens/playlist_detail_screen.dart';
import 'package:app/ui/screens/scan_wifi_network_screen.dart';
import 'package:app/ui/screens/send_wifi_credentials_screen.dart';
import 'package:app/ui/screens/work_detail_screen.dart';
import 'package:flutter/material.dart';
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

      // FF1 test route (for development/testing)
      GoRoute(
        path: Routes.ff1Test,
        name: RouteNames.ff1Test,
        builder: (context, state) => const FF1TestScreen(),
      ),

      // Connected devices route
      GoRoute(
        path: Routes.connectedDevices,
        name: RouteNames.connectedDevices,
        builder: (context, state) => const ConnectedDevicesScreen(),
      ),

      // Scan WiFi networks route (step 1-3 of connection)
      GoRoute(
        path: Routes.scanWifiNetworks,
        name: RouteNames.scanWifiNetworks,
        builder: (context, state) {
          final deviceJson = state.extra as Map<String, dynamic>?;
          if (deviceJson == null) {
            return const Scaffold(
              body: Center(child: Text('Device not found')),
            );
          }
          final device = FF1Device.fromJson(deviceJson);
          return ScanWiFiNetworkScreen(device: device);
        },
      ),

      // Enter WiFi password route (step 4-6 of connection)
      GoRoute(
        path: Routes.enterWifiPassword,
        name: RouteNames.enterWifiPassword,
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>?;
          if (args == null) {
            return const Scaffold(
              body: Center(child: Text('Invalid arguments')),
            );
          }
          final deviceJson = args['device'] as Map<String, dynamic>;
          final networkSsid = args['network'] as String;
          final device = FF1Device.fromJson(deviceJson);
          return EnterWiFiPasswordScreen(
            device: device,
            networkSsid: networkSsid,
          );
        },
      ),
    ],
  );
});
