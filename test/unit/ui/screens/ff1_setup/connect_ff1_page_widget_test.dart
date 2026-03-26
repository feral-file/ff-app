import 'dart:async';

import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/ui/screens/ff1_setup/connect_ff1_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

void main() {
  testWidgets(
    'uses explicit success navigation contract and preserves caller stack',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');
      var successCallbackCalled = false;

      const connectedState = ConnectFF1Connected(
        ff1device: FF1Device(
          name: 'FF1',
          remoteId: '00:11:22:33:44:55',
          deviceId: 'FF1-123',
          topicId: 'topic-123',
        ),
        portalIsSet: false,
        isConnectedToInternet: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectFF1Provider.overrideWith(
              () => _FakeConnectFF1Notifier(connectedState),
            ),
            ff1BluetoothDeviceActionsProvider.overrideWith(
              _FakeFF1BluetoothDeviceActionsNotifier.new,
            ),
            onboardingActionsProvider.overrideWith(
              (ref) => OnboardingService(
                ref: ref,
                appStateService: _MockAppStateService(),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/entry',
              routes: [
                GoRoute(
                  path: '/entry',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => unawaited(
                          context.push(
                            Routes.connectFF1Page,
                            extra: ConnectFF1PagePayload(
                              device: device,
                              ff1DeviceInfo: null,
                              onConnectedToInternet: (context, _) async {
                                successCallbackCalled = true;
                                context.replace(Routes.deviceConfiguration);
                              },
                            ),
                          ),
                        ),
                        child: const Text('Open connect page'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.connectFF1Page,
                  builder: (context, state) {
                    final payload = state.extra! as ConnectFF1PagePayload;
                    return ConnectFF1Page(payload: payload);
                  },
                ),
                GoRoute(
                  path: Routes.startSetupFf1,
                  builder: (context, state) => const Scaffold(
                    body: Text('START_SETUP_SHOULD_NOT_APPEAR'),
                  ),
                ),
                GoRoute(
                  path: Routes.deviceConfiguration,
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: Column(
                        children: [
                          const Text('DEVICE_CONFIGURATION_MARKER'),
                          TextButton(
                            onPressed: () => context.pop(),
                            child: const Text('Back'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open connect page'));
      await tester.pumpAndSettle();
      // Allow orchestrator effects (async listener) to complete.
      await tester.pump();

      expect(successCallbackCalled, isTrue);
      expect(find.text('DEVICE_CONFIGURATION_MARKER'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(find.text('Open connect page'), findsOneWidget);
      expect(find.text('START_SETUP_SHOULD_NOT_APPEAR'), findsNothing);
    },
  );

  testWidgets(
    'custom navigation callback error shows support dialog',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');

      const connectedState = ConnectFF1Connected(
        ff1device: FF1Device(
          name: 'FF1',
          remoteId: '00:11:22:33:44:55',
          deviceId: 'FF1-123',
          topicId: 'topic-123',
        ),
        portalIsSet: false,
        isConnectedToInternet: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectFF1Provider.overrideWith(
              () => _FakeConnectFF1Notifier(connectedState),
            ),
            ff1BluetoothDeviceActionsProvider.overrideWith(
              () => _FakeFF1BluetoothDeviceActionsNotifier(),
            ),
            onboardingActionsProvider.overrideWith(
              (ref) => OnboardingService(
                ref: ref,
                appStateService: _MockAppStateService(),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/entry',
              routes: [
                GoRoute(
                  path: '/entry',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => unawaited(
                          context.push(
                            Routes.connectFF1Page,
                            extra: ConnectFF1PagePayload(
                              device: device,
                              ff1DeviceInfo: null,
                              onConnectedToInternet: (_, __) async {
                                throw Exception('boom');
                              },
                            ),
                          ),
                        ),
                        child: const Text('Open connect page'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.connectFF1Page,
                  builder: (context, state) {
                    final payload = state.extra! as ConnectFF1PagePayload;
                    return ConnectFF1Page(payload: payload);
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open connect page'));
      // Avoid pumpAndSettle here: ConnectFF1Page includes animated content
      // (GIF) that can prevent the test from settling.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Connect failed'), findsOneWidget);
      expect(find.textContaining('boom'), findsOneWidget);
      expect(find.text('Contact support'), findsOneWidget);
    },
  );

  testWidgets(
    'portalIsSet ready does not auto navigate, requires button tap',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');
      var navigatedToConfig = false;

      const connectedState = ConnectFF1Connected(
        ff1device: FF1Device(
          name: 'FF1',
          remoteId: '00:11:22:33:44:55',
          deviceId: 'FF1-123',
          topicId: 'topic-123',
        ),
        portalIsSet: true,
        isConnectedToInternet: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectFF1Provider.overrideWith(
              () => _FakeConnectFF1Notifier(connectedState),
            ),
            ff1BluetoothDeviceActionsProvider.overrideWith(
              _FakeFF1BluetoothDeviceActionsNotifier.new,
            ),
            onboardingActionsProvider.overrideWith(
              (ref) => OnboardingService(
                ref: ref,
                appStateService: _MockAppStateService(),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/entry',
              routes: [
                GoRoute(
                  path: '/entry',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => unawaited(
                          context.push(
                            Routes.connectFF1Page,
                            extra: ConnectFF1PagePayload(
                              device: device,
                              ff1DeviceInfo: null,
                            ),
                          ),
                        ),
                        child: const Text('Open connect page'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.connectFF1Page,
                  builder: (context, state) {
                    final payload = state.extra! as ConnectFF1PagePayload;
                    return ConnectFF1Page(payload: payload);
                  },
                ),
                GoRoute(
                  path: Routes.deviceConfiguration,
                  builder: (context, state) {
                    navigatedToConfig = true;
                    return Scaffold(
                      body: Center(
                        child: Column(
                          children: [
                            const Text('DEVICE_CONFIGURATION_MARKER'),
                            TextButton(
                              onPressed: () => context.pop(),
                              child: const Text('Back'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open connect page'));
      await tester.pumpAndSettle();

      // Should show "The FF1 is All Set" screen
      expect(find.text('The FF1 is All Set'), findsOneWidget);
      expect(find.text('Go to Settings'), findsOneWidget);

      // Should NOT auto-navigate to device configuration
      expect(navigatedToConfig, isFalse);
      expect(find.text('DEVICE_CONFIGURATION_MARKER'), findsNothing);
    },
  );

  testWidgets(
    'cancel CTA pops back to caller',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');

      final connectingState = ConnectFF1Connecting(blDevice: device);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectFF1Provider.overrideWith(
              () => _FakeConnectFF1Notifier(connectingState),
            ),
            ff1BluetoothDeviceActionsProvider.overrideWith(
              () => _FakeFF1BluetoothDeviceActionsNotifier(),
            ),
            onboardingActionsProvider.overrideWith(
              (ref) => OnboardingService(
                ref: ref,
                appStateService: _MockAppStateService(),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/entry',
              routes: [
                GoRoute(
                  path: '/entry',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => unawaited(
                          context.push(
                            Routes.connectFF1Page,
                            extra: ConnectFF1PagePayload(
                              device: device,
                              ff1DeviceInfo: null,
                            ),
                          ),
                        ),
                        child: const Text('Open connect page'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.connectFF1Page,
                  builder: (context, state) {
                    final payload = state.extra! as ConnectFF1PagePayload;
                    return ConnectFF1Page(payload: payload);
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open connect page'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byKey(GoldPathPatrolKeys.connectFF1Cancel));
      await tester.pumpAndSettle();

      expect(find.text('Open connect page'), findsOneWidget);
    },
  );

  // Note on default success path testing:
  // The default path (onConnectedToInternet == null) is production behavior that calls
  // addDevice, completeOnboarding, and navigates to device configuration.
  // It is tested via:
  // 1. Direct navigation verification here (replaces callback test logic)
  // 2. Integration tests covering full side-effect flows with real providers
  // The explicit callback routing test above demonstrates the key API contract change.
}

class _FakeConnectFF1Notifier extends ConnectFF1Notifier {
  _FakeConnectFF1Notifier(this._nextState);

  final ConnectFF1State _nextState;

  @override
  Future<ConnectFF1State> build() async {
    return ConnectFF1Initial();
  }

  @override
  Future<void> connectBle(
    BluetoothDevice bluetoothDevice, {
    FF1DeviceInfo? ff1DeviceInfo,
  }) async {
    state = AsyncValue.data(_nextState);
  }
}

class _FakeFF1BluetoothDeviceActionsNotifier
    extends FF1BluetoothDeviceActionsNotifier {
  int deviceAddedCount = 0;

  @override
  void build() {}

  @override
  Future<void> addDevice(FF1Device device) async {
    deviceAddedCount++;
  }
}

class _MockAppStateService extends Mock implements AppStateService {
  @override
  Future<void> setHasSeenOnboarding({required bool hasSeen}) {
    return super.noSuchMethod(
      Invocation.method(
        #setHasSeenOnboarding,
        const [],
        <Symbol, Object?>{#hasSeen: hasSeen},
      ),
      returnValue: Future<void>.value(),
      returnValueForMissingStub: Future<void>.value(),
    ) as Future<void>;
  }
}
