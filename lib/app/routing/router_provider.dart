import 'package:app/app/route_observer.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/ui/screens/add_address_screen.dart';
import 'package:app/ui/screens/add_alias_screen.dart';
import 'package:app/ui/screens/all_channels_screen.dart';
import 'package:app/ui/screens/all_playlists_screen.dart';
import 'package:app/ui/screens/channel_detail_screen.dart';
import 'package:app/ui/screens/connected_devices_screen.dart';
import 'package:app/ui/screens/ff1_setup/ff1_device_picker_page.dart';
import 'package:app/ui/screens/ff1_setup/start_setup_ff1_page.dart';
import 'package:app/ui/screens/ff1_test_screen.dart';
import 'package:app/ui/screens/home_index_page.dart';
import 'package:app/ui/screens/onboarding/introduce_page.dart';
import 'package:app/ui/screens/onboarding/onboarding_add_address_page.dart';
import 'package:app/ui/screens/onboarding/setup_ff1_page.dart';
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
final routerProvider =
    Provider.family<GoRouter, String>((ref, initialLocation) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: initialLocation,
    observers: [routeObserver],
    routes: [
      // Onboarding routes (multi-step)
      GoRoute(
        path: Routes.onboarding,
        name: RouteNames.onboarding,
        redirect: (context, state) {
          // Only redirect if we're exactly at /onboarding, not at a child route
          if (state.uri.path == Routes.onboarding) {
            return Routes.onboardingIntroducePage;
          }
          return null; // No redirect for child routes
        },
        routes: [
          GoRoute(
            path: 'introduce',
            name: RouteNames.onboardingIntroduce,
            builder: (context, state) {
              final payload = state.extra! as IntroducePagePayload;
              return IntroducePage(payload: payload);
            },
          ),
          GoRoute(
            path: 'add-address',
            name: RouteNames.onboardingAddAddress,
            builder: (context, state) {
              final payload = state.extra! as OnboardingAddAddressPagePayload;
              return OnboardingAddAddressPage(payload: payload);
            },
          ),
          GoRoute(
            path: 'setup-ff1',
            name: RouteNames.onboardingSetupFf1,
            builder: (context, state) => const OnboardingSetupFf1Page(),
          ),
        ],
      ),

      // FF1 device picker page route path.
      GoRoute(
        path: Routes.ff1DevicePickerPage,
        name: RouteNames.ff1DevicePicker,
        builder: (context, state) => const FF1DevicePickerPage(),
      ),

      // Add address input page
      GoRoute(
        path: Routes.addAddressPage,
        name: RouteNames.addAddress,
        builder: (context, state) => const AddAddressScreen(),
      ),

      // Add alias page
      GoRoute(
        path: Routes.addAliasPage,
        name: RouteNames.addAlias,
        builder: (context, state) {
          final payload = state.extra! as AddAliasScreenPayload;
          if (payload.address.isEmpty) {
            // If no address provided, go back
            return const AddAddressScreen();
          }

          return AddAliasScreen(payload: payload);
        },
      ),

      // Home route with tabs (playlists, channels, works, search)
      GoRoute(
        path: Routes.home,
        name: RouteNames.home,
        builder: (context, state) => const HomeIndexPage(),
      ),

      // All channels route (must be defined before channel detail so "all" isn't
      // interpreted as a channelId).
      GoRoute(
        path: Routes.allChannels,
        name: RouteNames.allChannels,
        builder: (context, state) {
          final filterParam = state.uri.queryParameters['filter'];
          final filter = filterParam == 'personal'
              ? AllChannelsFilter.personal
              : AllChannelsFilter.curated;
          return AllChannelsScreen(filter: filter);
        },
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

      // All playlists route (must be defined before playlist detail so "all"
      // isn't interpreted as a playlistId).
      GoRoute(
        path: Routes.allPlaylists,
        name: RouteNames.allPlaylists,
        builder: (context, state) {
          final filterParam = state.uri.queryParameters['filter'];
          final filter = filterParam == 'personal'
              ? AllPlaylistsFilter.personal
              : AllPlaylistsFilter.curated;
          return AllPlaylistsScreen(filter: filter);
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

      // // Device configuration route
      // GoRoute(
      //   path: Routes.deviceConfiguration,
      //   name: RouteNames.deviceConfiguration,
      //   builder: (context, state) {
      //     final args = state.extra as Map<String, dynamic>?;
      //     if (args == null) {
      //       return const Scaffold(
      //         body: Center(child: Text('Invalid arguments')),
      //       );
      //     }
      //     return DeviceConfigScreen(
      //       payload: DeviceConfigPayload(
      //         isFromOnboarding: args['isFromOnboarding'] as bool,
      //       ),
      //     );
      //   },
      // ),
    ],
  );
});
