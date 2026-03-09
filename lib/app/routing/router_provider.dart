import 'package:app/app/providers/current_route_provider.dart';
import 'package:app/app/route_observer.dart';
import 'package:app/app/routing/app_navigator_key.dart';
import 'package:app/app/routing/app_route_observer.dart';
import 'package:app/app/routing/page_transitions.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/infra/services/release_notes_service.dart';
import 'package:app/ui/screens/add_address_screen.dart';
import 'package:app/ui/screens/add_alias_screen.dart';
import 'package:app/ui/screens/all_channels_screen.dart';
import 'package:app/ui/screens/all_playlists_screen.dart';
import 'package:app/ui/screens/channel_detail_screen.dart';
import 'package:app/ui/screens/device_config_screen.dart';
import 'package:app/ui/screens/ff1_setup/connect_ff1_page.dart';
import 'package:app/ui/screens/ff1_setup/ff1_device_picker_page.dart';
import 'package:app/ui/screens/ff1_setup/ff1_updating_page.dart';
import 'package:app/ui/screens/ff1_setup/start_setup_ff1_page.dart';
import 'package:app/ui/screens/ff1_test_screen.dart';
import 'package:app/ui/screens/home_index_page.dart';
import 'package:app/ui/screens/keyboard_control_screen.dart';
import 'package:app/ui/screens/now_displaying_screen.dart';
import 'package:app/ui/screens/onboarding/introduce_page.dart';
import 'package:app/ui/screens/onboarding/onboarding_add_address_page.dart';
import 'package:app/ui/screens/onboarding/setup_ff1_page.dart';
import 'package:app/ui/screens/playlist_detail_screen.dart';
import 'package:app/ui/screens/release_note_detail_screen.dart';
import 'package:app/ui/screens/release_notes_screen.dart';
import 'package:app/ui/screens/scan_qr_page.dart';
import 'package:app/ui/screens/scan_wifi_network_screen.dart';
import 'package:app/ui/screens/send_wifi_credentials_screen.dart';
import 'package:app/ui/screens/settings/document_viewer_page.dart';
import 'package:app/ui/screens/settings/settings_page.dart';
import 'package:app/ui/screens/work_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

final _log = Logger('RouterProvider');

/// Master router provider using go_router.
/// This is the single source of truth for navigation in the app.
/// All navigation state flows through Riverpod.
///
/// Note: List views (channels, playlists, works) are now tabs in HomeIndexPage.
/// Only detail screens have dedicated routes.
final Provider<GoRouter> Function(String)
routerProvider = Provider.family<GoRouter, String>((
  ref,
  initialLocation,
) {
  return GoRouter(
    navigatorKey: appNavigatorKey,
    debugLogDiagnostics: true,
    initialLocation: initialLocation,
    observers: [
      routeObserver,
      AppRouteObserver(
        onRouteChanged: (path, currentRoute) {
          // Defer to avoid "modify provider while building" when observer
          // fires during Navigator restoreState/didChangeDependencies.
          Future.microtask(() {
            ref.read(currentRouteProvider.notifier).update(path, currentRoute);
          });
        },
      ),
    ],
    // Deep links like device_connect are handled by DeeplinkHandler via
    // app_links, not by GoRouter route matching. When Flutter's
    // RouteInformationProvider also forwards the same URL to GoRouter
    // (e.g. on a cold-start from a universal link), we redirect to the
    // initial location so GoRouter doesn't throw and DeeplinkHandler
    // still processes the link correctly.
    redirect: (context, state) {
      final path = state.uri.path;
      if (path.startsWith('/device_connect')) {
        return initialLocation;
      }
      return null;
    },
    // Safety net: redirect to initialLocation for any URL that doesn't
    // match a registered route (e.g. future deep link schemes not yet
    // known to GoRouter).
    onException: (context, state, router) {
      _log.warning('No route found for: ${state.uri}; redirecting to $initialLocation');
      router.go(initialLocation);
    },
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
            pageBuilder: (context, state) {
              final payload = state.extra is IntroducePagePayload
                  ? state.extra! as IntroducePagePayload
                  : IntroducePagePayload();
              return buildCupertinoTransitionPage(
                context,
                state,
                IntroducePage(payload: payload),
              );
            },
          ),
          GoRoute(
            path: 'add-address',
            name: RouteNames.onboardingAddAddress,
            pageBuilder: (context, state) {
              final payload = state.extra is OnboardingAddAddressPagePayload
                  ? state.extra! as OnboardingAddAddressPagePayload
                  : OnboardingAddAddressPagePayload();
              return buildCupertinoTransitionPage(
                context,
                state,
                OnboardingAddAddressPage(payload: payload),
              );
            },
          ),
          GoRoute(
            path: 'setup-ff1',
            name: RouteNames.onboardingSetupFf1,
            pageBuilder: (context, state) => buildCupertinoTransitionPage(
              context,
              state,
              const OnboardingSetupFf1Page(),
            ),
          ),
        ],
      ),
      // FF1 device picker page route path.
      GoRoute(
        path: Routes.ff1DevicePickerPage,
        name: RouteNames.ff1DevicePicker,
        pageBuilder: (context, state) => buildCupertinoTransitionPage(
          context,
          state,
          const FF1DevicePickerPage(),
        ),
      ),

      // Global QR scan route.
      GoRoute(
        path: Routes.scanQrPage,
        name: RouteNames.scanQrPage,
        pageBuilder: (context, state) {
          final payload = state.extra is ScanQrPagePayload
              ? state.extra! as ScanQrPagePayload
              : const ScanQrPagePayload();
          return buildCupertinoTransitionPage(
            context,
            state,
            ScanQrPage(payload: payload),
          );
        },
      ),

      // Add address input page
      GoRoute(
        path: Routes.addAddressPage,
        name: RouteNames.addAddress,
        pageBuilder: (context, state) {
          return buildCupertinoTransitionPage(
            context,
            state,
            const AddAddressScreen(),
          );
        },
      ),

      // Add alias page
      GoRoute(
        path: Routes.addAliasPage,
        name: RouteNames.addAlias,
        pageBuilder: (context, state) {
          if (state.extra == null) {
            _log.warning('AddAliasScreen: extra is null');
            context.pop();
            return buildCupertinoTransitionPage(
              context,
              state,
              const SizedBox.shrink(),
            );
          }

          final payload = state.extra! as AddAliasScreenPayload;
          if (payload.address.isEmpty) {
            _log.warning('AddAliasScreen: address is empty');
            context.pop();
            return buildCupertinoTransitionPage(
              context,
              state,
              const SizedBox.shrink(),
            );
          }

          return buildCupertinoTransitionPage(
            context,
            state,
            AddAliasScreen(payload: payload),
          );
        },
      ),

      // Home route with tabs (playlists, channels, works, search)
      GoRoute(
        path: Routes.home,
        name: RouteNames.home,
        builder: (context, state) => const HomeIndexPage(),
      ),

      // Release notes list route.
      GoRoute(
        path: Routes.releaseNotes,
        name: RouteNames.releaseNotes,
        pageBuilder: (context, state) => buildCupertinoTransitionPage(
          context,
          state,
          const ReleaseNotesScreen(),
        ),
      ),

      // Settings (Account) route.
      GoRoute(
        path: Routes.settings,
        name: RouteNames.settings,
        pageBuilder: (context, state) => buildCupertinoTransitionPage(
          context,
          state,
          const SettingsPage(),
        ),
        routes: [
          GoRoute(
            path: 'eula',
            name: RouteNames.settingsEula,
            pageBuilder: (context, state) => buildCupertinoTransitionPage(
              context,
              state,
              const DocumentViewerPage(document: SettingsDocument.eula),
            ),
          ),
          GoRoute(
            path: 'privacy',
            name: RouteNames.settingsPrivacy,
            pageBuilder: (context, state) => buildCupertinoTransitionPage(
              context,
              state,
              const DocumentViewerPage(document: SettingsDocument.privacy),
            ),
          ),
        ],
      ),

      // Release note detail route.
      GoRoute(
        path: Routes.releaseNoteDetail,
        name: RouteNames.releaseNoteDetail,
        pageBuilder: (context, state) {
          if (state.extra is! ReleaseNoteEntry) {
            _log.warning('ReleaseNoteDetailScreen: extra is invalid');
            context.pop();
            return buildCupertinoTransitionPage(
              context,
              state,
              const SizedBox.shrink(),
            );
          }
          return buildCupertinoTransitionPage(
            context,
            state,
            ReleaseNoteDetailScreen(
              releaseNote: state.extra! as ReleaseNoteEntry,
            ),
          );
        },
      ),

      // All channels route (must be defined before channel detail so "all"
      // isn't interpreted as a channelId).
      GoRoute(
        path: Routes.allChannels,
        name: RouteNames.allChannels,
        pageBuilder: (context, state) {
          final filterParam = state.uri.queryParameters['filter'];
          final filter = filterParam == 'personal'
              ? AllChannelsFilter.personal
              : AllChannelsFilter.curated;
          return buildCupertinoTransitionPage(
            context,
            state,
            AllChannelsScreen(filter: filter),
          );
        },
      ),

      // Channel detail route
      GoRoute(
        path: '${Routes.channels}/:channelId',
        name: RouteNames.channelDetail,
        pageBuilder: (context, state) {
          final channelId = state.pathParameters['channelId']!;
          return buildCupertinoTransitionPage(
            context,
            state,
            ChannelDetailScreen(channelId: channelId),
          );
        },
      ),

      // All playlists route (must be defined before playlist detail so "all"
      // isn't interpreted as a playlistId).
      GoRoute(
        path: Routes.allPlaylists,
        name: RouteNames.allPlaylists,
        pageBuilder: (context, state) {
          final filterParam = state.uri.queryParameters['filter'];
          final filter = filterParam == 'personal'
              ? AllPlaylistsFilter.personal
              : AllPlaylistsFilter.curated;
          return buildCupertinoTransitionPage(
            context,
            state,
            AllPlaylistsScreen(filter: filter),
          );
        },
      ),

      // Playlist detail route
      GoRoute(
        path: '${Routes.playlists}/:playlistId',
        name: RouteNames.playlistDetail,
        pageBuilder: (context, state) {
          final playlistId = state.pathParameters['playlistId']!;
          return buildCupertinoTransitionPage(
            context,
            state,
            PlaylistDetailScreen(playlistId: playlistId),
          );
        },
      ),

      // Work detail route
      GoRoute(
        path: '${Routes.works}/:workId',
        name: RouteNames.workDetail,
        pageBuilder: (context, state) {
          final workId = state.pathParameters['workId']!;
          return buildCupertinoTransitionPage(
            context,
            state,
            WorkDetailScreen(workId: workId),
          );
        },
      ),

      // FF1 test route (for development/testing)
      GoRoute(
        path: Routes.ff1Test,
        name: RouteNames.ff1Test,
        pageBuilder: (context, state) => buildCupertinoTransitionPage(
          context,
          state,
          const FF1TestScreen(),
        ),
      ),

      // Now displaying (full-screen) route
      GoRoute(
        path: Routes.nowDisplaying,
        name: RouteNames.nowDisplaying,
        pageBuilder: (context, state) => buildCupertinoTransitionPage(
          context,
          state,
          const NowDisplayingScreen(),
        ),
      ),

      // Keyboard control (interact) route
      GoRoute(
        path: Routes.keyboardControl,
        name: RouteNames.keyboardControl,
        pageBuilder: (context, state) => buildCupertinoTransitionPage(
          context,
          state,
          const KeyboardControlScreen(),
        ),
      ),

      // Start setup FF1 route
      GoRoute(
        path: Routes.startSetupFf1,
        name: RouteNames.startSetupFf1,
        pageBuilder: (context, state) {
          final payload = state.extra is StartSetupFf1PagePayload
              ? state.extra! as StartSetupFf1PagePayload
              : StartSetupFf1PagePayload();
          return buildCupertinoTransitionPage(
            context,
            state,
            StartSetupFf1Page(payload: payload),
          );
        },
      ),

      // Connect FF1 page route.
      GoRoute(
        path: Routes.connectFF1Page,
        name: RouteNames.connectFF1,
        pageBuilder: (context, state) {
          if (state.extra == null) {
            _log.warning('ConnectFF1Page: extra is null');
            context.pop();
            return buildCupertinoTransitionPage(
              context,
              state,
              const SizedBox.shrink(),
            );
          }

          final payload = state.extra! as ConnectFF1PagePayload;
          return buildCupertinoTransitionPage(
            context,
            state,
            ConnectFF1Page(payload: payload),
          );
        },
      ),

      // Scan WiFi networks route (step 1-3 of connection)
      GoRoute(
        path: Routes.scanWifiNetworks,
        name: RouteNames.scanWifiNetworks,
        pageBuilder: (context, state) {
          if (state.extra == null) {
            _log.warning('ScanWiFiNetworkScreen: extra is null');
            context.pop();
            return buildCupertinoTransitionPage(
              context,
              state,
              const SizedBox.shrink(),
            );
          }

          final payload = state.extra! as ScanWifiNetworkPagePayload;
          return buildCupertinoTransitionPage(
            context,
            state,
            ScanWiFiNetworkScreen(payload: payload),
          );
        },
      ),

      // Enter WiFi password route (step 4-6 of connection)
      GoRoute(
        path: Routes.enterWifiPassword,
        name: RouteNames.enterWifiPassword,
        pageBuilder: (context, state) {
          final payload = state.extra! as EnterWifiPasswordPagePayload;
          return buildCupertinoTransitionPage(
            context,
            state,
            EnterWiFiPasswordScreen(payload: payload),
          );
        },
      ),

      // Device configuration route
      GoRoute(
        path: Routes.deviceConfiguration,
        name: RouteNames.deviceConfiguration,
        pageBuilder: (context, state) {
          final payload = state.extra is DeviceConfigPayload
              ? state.extra! as DeviceConfigPayload
              : DeviceConfigPayload();
          return buildCupertinoTransitionPage(
            context,
            state,
            DeviceConfigScreen(payload: payload),
          );
        },
      ),

      // FF1 updating route
      GoRoute(
        path: Routes.ff1Updating,
        name: RouteNames.ff1Updating,
        pageBuilder: (context, state) => buildCupertinoTransitionPage(
          context,
          state,
          const FF1UpdatingPage(),
        ),
      ),
    ],
  );
});
