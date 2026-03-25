import 'dart:async';

import 'package:app/app/providers/current_route_provider.dart';
import 'package:app/app/route_observer.dart';
import 'package:app/app/routing/all_playlists_route.dart'
    show deriveAllPlaylistsMetadata, parseAllPlaylistsQuery;
import 'package:app/app/routing/app_navigator_key.dart';
import 'package:app/app/routing/app_route_observer.dart';
import 'package:app/app/routing/page_transitions.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/infra/logging/structured_log_context.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:app/infra/services/release_notes_service.dart';
import 'package:app/ui/screens/add_address_screen.dart';
import 'package:app/ui/screens/add_alias_screen.dart';
import 'package:app/ui/screens/all_channels_screen.dart';
import 'package:app/ui/screens/all_playlists_screen.dart' show AllPlaylistsScreen;
import 'package:app/ui/screens/channel_detail_screen.dart';
import 'package:app/ui/screens/device_config_screen.dart';
import 'package:app/ui/screens/ff1_setup/connect_ff1_page.dart';
import 'package:app/ui/screens/ff1_setup/ff1_device_scan_page.dart';
import 'package:app/ui/screens/ff1_setup/ff1_updating_page.dart';
import 'package:app/ui/screens/ff1_setup/start_setup_ff1_page.dart';
import 'package:app/ui/screens/ff1_test_screen.dart';
import 'package:app/ui/screens/home_index_page.dart';
import 'package:app/ui/screens/keyboard_control_screen.dart';
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

final Logger _log = Logger('RouterProvider');
final StructuredLogger _routeLog = AppStructuredLog.forLogger(
  _log,
  context: {'layer': 'routing'},
);

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
  StructuredLogContext.updateCurrentRoute(initialLocation);
  return GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: initialLocation,
    observers: [
      routeObserver,
      AppRouteObserver(
        onRouteChanged:
            ({
              required fromPath,
              required toPath,
              required currentRoute,
            }) {
              StructuredLogContext.updateCurrentRoute(toPath);
              _routeLog.info(
                category: LogCategory.route,
                event: 'screen_viewed',
                message: 'viewed ${_screenNameForRoute(toPath)}',
                payload: {
                  'fromRoute': fromPath,
                  'toRoute': toPath,
                  'screenViewed': _screenNameForRoute(toPath),
                },
              );
              // Defer to avoid "modify provider while building" when observer
              // fires during Navigator restoreState/didChangeDependencies.
              unawaited(
                Future.microtask(() {
                  ref
                      .read(currentRouteProvider.notifier)
                      .update(toPath, currentRoute);
                }),
              );
            },
      ),
    ],
    // Catch-all for routing exceptions (unmatched routes, missing parameters,
    // navigation errors). For unknown routes, redirect to initialLocation.
    // /device_connect deep links are silently ignored because they are handled
    // externally by the deep-link handler before GoRouter sees them.
    onException: (context, state, router) {
      final path = state.uri.path;
      if (path.startsWith('/device_connect')) {
        _log.info('Ignore onException for deeplink: $path');
        return;
      }

      _routeLog.warning(
        category: LogCategory.route,
        event: 'route_not_found',
        message: 'unknown route $path; redirecting',
        payload: {
          'fromRoute': path,
          'toRoute': initialLocation,
        },
      );

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
      // FF1 device scan page route path.
      GoRoute(
        path: Routes.ff1DeviceScanPage,
        name: RouteNames.ff1DeviceScan,
        pageBuilder: (context, state) {
          final payload = state.extra is FF1DeviceScanPagePayload
              ? state.extra! as FF1DeviceScanPagePayload
              : FF1DeviceScanPagePayload();
          return buildCupertinoTransitionPage(
            context,
            state,
            FF1DeviceScanPage(payload: payload),
          );
        },
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
            _routeLog.warning(
              category: LogCategory.route,
              event: 'route_payload_missing',
              message: 'AddAliasScreen payload missing',
              payload: {'route': Routes.addAliasPage},
            );
            context.pop();
            return buildCupertinoTransitionPage(
              context,
              state,
              const SizedBox.shrink(),
            );
          }

          final payload = state.extra! as AddAliasScreenPayload;
          if (payload.address.isEmpty) {
            _routeLog.warning(
              category: LogCategory.route,
              event: 'route_payload_invalid',
              message: 'AddAliasScreen payload address empty',
              payload: {'route': Routes.addAliasPage},
            );
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
            _routeLog.warning(
              category: LogCategory.route,
              event: 'route_payload_invalid',
              message: 'ReleaseNoteDetailScreen payload invalid',
              payload: {'route': Routes.releaseNoteDetail},
            );
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
          final params = parseAllPlaylistsQuery(state.uri.queryParameters);
          final metadata = deriveAllPlaylistsMetadata(params);
          return buildCupertinoTransitionPage(
            context,
            state,
            AllPlaylistsScreen(
              channelTypes: params.channelTypes,
              channelIds: params.channelIds,
              playlistTypes: params.playlistTypes,
              title: metadata.title,
              description: metadata.description,
              iconAsset: metadata.iconAsset,
            ),
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
            _routeLog.warning(
              category: LogCategory.route,
              event: 'route_payload_missing',
              message: 'ConnectFF1Page payload missing',
              payload: {'route': Routes.connectFF1Page},
            );
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
            _routeLog.warning(
              category: LogCategory.route,
              event: 'route_payload_missing',
              message: 'ScanWiFiNetworkScreen payload missing',
              payload: {'route': Routes.scanWifiNetworks},
            );
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

String _screenNameForRoute(String path) {
  final normalized = path.trim();
  if (normalized.isEmpty || normalized == '/') {
    return 'HomeIndexPage';
  }

  for (final mapping in _routeScreenMappings) {
    if (mapping.matches(normalized)) {
      return mapping.screenName;
    }
  }

  return 'UnknownScreen';
}

final List<_RouteScreenMapping> _routeScreenMappings = [
  _RouteScreenMapping(
    screenName: 'HomeIndexPage',
    matches: (path) => path == Routes.home,
  ),
  _RouteScreenMapping(
    screenName: 'OnboardingIntroducePage',
    matches: (path) => path == Routes.onboardingIntroducePage,
  ),
  _RouteScreenMapping(
    screenName: 'OnboardingAddAddressPage',
    matches: (path) => path == Routes.onboardingAddAddressPage,
  ),
  _RouteScreenMapping(
    screenName: 'OnboardingSetupFf1Page',
    matches: (path) => path == Routes.onboardingSetupFf1Page,
  ),
  _RouteScreenMapping(
    screenName: 'FF1DeviceScanPage',
    matches: (path) => path == Routes.ff1DeviceScanPage,
  ),
  _RouteScreenMapping(
    screenName: 'ScanQrPage',
    matches: (path) => path == Routes.scanQrPage,
  ),
  _RouteScreenMapping(
    screenName: 'AddAddressScreen',
    matches: (path) => path == Routes.addAddressPage,
  ),
  _RouteScreenMapping(
    screenName: 'AddAliasScreen',
    matches: (path) => path == Routes.addAliasPage,
  ),
  _RouteScreenMapping(
    screenName: 'ReleaseNotesScreen',
    matches: (path) => path == Routes.releaseNotes,
  ),
  _RouteScreenMapping(
    screenName: 'ReleaseNoteDetailScreen',
    matches: (path) =>
        path == Routes.releaseNoteDetail ||
        path.startsWith('${Routes.releaseNotes}/'),
  ),
  _RouteScreenMapping(
    screenName: 'AllChannelsScreen',
    matches: (path) => path == Routes.allChannels,
  ),
  _RouteScreenMapping(
    screenName: 'ChannelDetailScreen',
    matches: (path) =>
        path.startsWith('${Routes.channels}/') && path != Routes.allChannels,
  ),
  _RouteScreenMapping(
    screenName: 'AllPlaylistsScreen',
    matches: (path) => path == Routes.allPlaylists,
  ),
  _RouteScreenMapping(
    screenName: 'PlaylistDetailScreen',
    matches: (path) =>
        path.startsWith('${Routes.playlists}/') && path != Routes.allPlaylists,
  ),
  _RouteScreenMapping(
    screenName: 'WorkDetailScreen',
    matches: (path) => path.startsWith('${Routes.works}/'),
  ),
  _RouteScreenMapping(
    screenName: 'KeyboardControlScreen',
    matches: (path) => path == Routes.keyboardControl,
  ),
  _RouteScreenMapping(
    screenName: 'StartSetupFf1Page',
    matches: (path) => path == Routes.startSetupFf1,
  ),
  _RouteScreenMapping(
    screenName: 'ConnectFF1Page',
    matches: (path) => path == Routes.connectFF1Page,
  ),
  _RouteScreenMapping(
    screenName: 'ScanWiFiNetworkScreen',
    matches: (path) => path == Routes.scanWifiNetworks,
  ),
  _RouteScreenMapping(
    screenName: 'EnterWiFiPasswordScreen',
    matches: (path) => path == Routes.enterWifiPassword,
  ),
  _RouteScreenMapping(
    screenName: 'DeviceConfigScreen',
    matches: (path) => path == Routes.deviceConfiguration,
  ),
  _RouteScreenMapping(
    screenName: 'FF1UpdatingPage',
    matches: (path) => path == Routes.ff1Updating,
  ),
  _RouteScreenMapping(
    screenName: 'SettingsPage',
    matches: (path) =>
        path == Routes.settings ||
        path == Routes.settingsEula ||
        path == Routes.settingsPrivacy,
  ),
];

class _RouteScreenMapping {
  const _RouteScreenMapping({
    required this.screenName,
    required this.matches,
  });

  final String screenName;
  final bool Function(String path) matches;
}
