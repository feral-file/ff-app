import 'dart:async';

import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/app_navigator_key.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:app/ui/screens/ff1_setup/connect_ff1_page.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';

void main() {
  testWidgets(
    'internet-ready without guided session completes onboarding and replaces '
    'to device configuration when portal is not set',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');
      final appState = _MockAppStateService();

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

      final container = ProviderContainer(
        overrides: [
          connectFF1Provider.overrideWith(
            () => _FakeConnectFF1Notifier(connectedState),
          ),
          connectWiFiProvider.overrideWith(_IdleWifiNotifier.new),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          ff1BluetoothDeviceActionsProvider.overrideWith(
            _FakeFF1BluetoothDeviceActionsNotifier.new,
          ),
          onboardingActionsProvider.overrideWith(
            (ref) => OnboardingService(
              ref: ref,
              appStateService: appState,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              navigatorKey: appNavigatorKey,
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
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open connect page'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpAndSettle();

      expect(find.text('DEVICE_CONFIGURATION_MARKER'), findsOneWidget);
      expect(find.text('START_SETUP_SHOULD_NOT_APPEAR'), findsNothing);
      expect(
        container.read(ff1SetupOrchestratorProvider).step,
        FF1SetupStep.idle,
      );
      expect(
        container.read(connectFF1Provider).asData?.value,
        isA<ConnectFF1Initial>(),
      );
      verify(appState.setHasSeenOnboarding(hasSeen: true)).called(1);
    },
  );

  testWidgets(
    'guided non-portal completion latches success UI until navigation finishes',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');
      final addDeviceCompleter = Completer<void>();
      var navigatedToConfig = false;

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

      final container = ProviderContainer(
        overrides: [
          connectFF1Provider.overrideWith(
            () => _FakeConnectFF1Notifier(connectedState),
          ),
          connectWiFiProvider.overrideWith(_IdleWifiNotifier.new),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          ff1BluetoothDeviceActionsProvider.overrideWith(
            () =>
                _BlockingFF1BluetoothDeviceActionsNotifier(addDeviceCompleter),
          ),
          onboardingActionsProvider.overrideWith(
            (ref) => OnboardingService(
              ref: ref,
              appStateService: _MockAppStateService(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(ff1SetupOrchestratorProvider.notifier).startSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              navigatorKey: appNavigatorKey,
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
                    return const Scaffold(
                      body: Text('DEVICE_CONFIGURATION_MARKER'),
                    );
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

      expect(
        tester
            .widget<ElevatedButton>(
              find
                  .descendant(
                    of: find.byType(PrimaryButton),
                    matching: find.byType(ElevatedButton),
                  )
                  .last,
            )
            .onPressed,
        isNull,
      );
      expect(find.text('Connected to FF1'), findsOneWidget);

      await tester.tap(find.byKey(GoldPathPatrolKeys.connectFF1Cancel));
      await tester.pump();
      expect(find.text('Connected to FF1'), findsOneWidget);
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNotNull,
      );

      addDeviceCompleter.complete();
      await tester.pump();

      expect(navigatedToConfig, isTrue);
      expect(find.text('Connecting via Bluetooth...'), findsNothing);
      await tester.pumpAndSettle();

      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNull,
      );
      expect(find.text('DEVICE_CONFIGURATION_MARKER'), findsOneWidget);
    },
  );

  testWidgets(
    'portalIsSet without active setup session tears down on Go to Settings',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');
      var navigatedToConfig = false;
      final appState = _MockAppStateService();

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

      final container = ProviderContainer(
        overrides: [
          connectFF1Provider.overrideWith(
            () => _FakeConnectFF1Notifier(connectedState),
          ),
          connectWiFiProvider.overrideWith(_IdleWifiNotifier.new),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          ff1BluetoothDeviceActionsProvider.overrideWith(
            _FakeFF1BluetoothDeviceActionsNotifier.new,
          ),
          onboardingActionsProvider.overrideWith(
            (ref) => OnboardingService(
              ref: ref,
              appStateService: appState,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      const portalDeeplinkInfo = FF1DeviceInfo(
        deviceId: 'FF1-123',
        topicId: 'topic-123',
        isConnectedToInternet: true,
        branchName: 'release',
        version: '1.0.0',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              navigatorKey: appNavigatorKey,
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
                              ff1DeviceInfo: portalDeeplinkInfo,
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
      await tester.tap(find.text('Go to Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(navigatedToConfig, isTrue);
      expect(find.text('DEVICE_CONFIGURATION_MARKER'), findsOneWidget);
      expect(
        container.read(ff1SetupOrchestratorProvider).step,
        FF1SetupStep.idle,
      );
      expect(
        container.read(connectFF1Provider).asData?.value,
        isA<ConnectFF1Initial>(),
      );
      verify(appState.setHasSeenOnboarding(hasSeen: true)).called(1);
    },
  );

  testWidgets(
    'guided cancel abandons setup session before popping back',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');

      final connectingState = ConnectFF1Connecting(blDevice: device);
      final container = ProviderContainer(
        overrides: [
          connectFF1Provider.overrideWith(
            () => _FakeConnectFF1Notifier(connectingState),
          ),
          connectWiFiProvider.overrideWith(_IdleWifiNotifier.new),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
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
      );
      addTearDown(container.dispose);
      container.read(ff1SetupOrchestratorProvider.notifier).startSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              navigatorKey: appNavigatorKey,
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
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNull,
      );
      expect(
        container.read(ff1SetupOrchestratorProvider).step,
        FF1SetupStep.idle,
      );
    },
  );

  testWidgets(
    'late guided success is ignored after session cancel',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');
      var navigatedToConfig = false;
      final connectRelease = Completer<void>();

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

      final connectNotifier = _GatedFakeConnectFF1Notifier(
        release: connectRelease.future,
        nextState: connectedState,
      );
      final container = ProviderContainer(
        overrides: [
          connectFF1Provider.overrideWith(() => connectNotifier),
          connectWiFiProvider.overrideWith(_IdleWifiNotifier.new),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
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
      );
      addTearDown(container.dispose);
      container.read(ff1SetupOrchestratorProvider.notifier).startSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              navigatorKey: appNavigatorKey,
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
                    return const Scaffold(
                      body: Text('DEVICE_CONFIGURATION_MARKER'),
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

      await container
          .read(ff1SetupOrchestratorProvider.notifier)
          .cancelSession(FF1SetupSessionCancelReason.userAborted);

      connectRelease.complete();
      await tester.pump();

      await tester.pump();
      await tester.pumpAndSettle();

      expect(navigatedToConfig, isFalse);
      expect(find.text('DEVICE_CONFIGURATION_MARKER'), findsNothing);
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNull,
      );
    },
  );

  testWidgets(
    'portalIsSet Go to Settings disabled until guided completion finishes',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');
      var navigatedToConfig = false;
      final addDeviceCompleter = Completer<void>();

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

      final container = ProviderContainer(
        overrides: [
          connectFF1Provider.overrideWith(
            () => _FakeConnectFF1Notifier(connectedState),
          ),
          connectWiFiProvider.overrideWith(_IdleWifiNotifier.new),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          ff1BluetoothDeviceActionsProvider.overrideWith(
            () =>
                _BlockingFF1BluetoothDeviceActionsNotifier(addDeviceCompleter),
          ),
          onboardingActionsProvider.overrideWith(
            (ref) => OnboardingService(
              ref: ref,
              appStateService: _MockAppStateService(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(ff1SetupOrchestratorProvider.notifier).startSession();

      const portalDeeplinkInfo = FF1DeviceInfo(
        deviceId: 'FF1-123',
        topicId: 'topic-123',
        isConnectedToInternet: true,
        branchName: 'release',
        version: '1.0.0',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              navigatorKey: appNavigatorKey,
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
                              ff1DeviceInfo: portalDeeplinkInfo,
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
                    return const Scaffold(
                      body: Text('DEVICE_CONFIGURATION_MARKER'),
                    );
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

      expect(find.text('The FF1 is All Set'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find
                  .descendant(
                    of: find.byType(PrimaryButton),
                    matching: find.byType(ElevatedButton),
                  )
                  .first,
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Go to Settings'));
      await tester.pump();

      expect(navigatedToConfig, isFalse);

      addDeviceCompleter.complete();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ElevatedButton>(
              find
                  .descendant(
                    of: find.byType(PrimaryButton),
                    matching: find.byType(ElevatedButton),
                  )
                  .first,
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Go to Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(navigatedToConfig, isTrue);
      expect(find.text('DEVICE_CONFIGURATION_MARKER'), findsOneWidget);
    },
  );

  testWidgets(
    'guided portal completion failure stays retryable from the same screen',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');
      final retryingActions = _FailOnceFF1BluetoothDeviceActionsNotifier();
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

      final container = ProviderContainer(
        overrides: [
          connectFF1Provider.overrideWith(
            () => _FakeConnectFF1Notifier(connectedState),
          ),
          connectWiFiProvider.overrideWith(_IdleWifiNotifier.new),
          ff1ControlProvider.overrideWithValue(
            FF1BleControl(transport: _NoopBleTransport()),
          ),
          ff1BluetoothDeviceActionsProvider.overrideWith(
            () => retryingActions,
          ),
          onboardingActionsProvider.overrideWith(
            (ref) => OnboardingService(
              ref: ref,
              appStateService: _MockAppStateService(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(ff1SetupOrchestratorProvider.notifier).startSession();

      const portalDeeplinkInfo = FF1DeviceInfo(
        deviceId: 'FF1-123',
        topicId: 'topic-123',
        isConnectedToInternet: true,
        branchName: 'release',
        version: '1.0.0',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              navigatorKey: appNavigatorKey,
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
                              ff1DeviceInfo: portalDeeplinkInfo,
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
                    return const Scaffold(
                      body: Text('DEVICE_CONFIGURATION_MARKER'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open connect page'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Setup could not finish'), findsOneWidget);
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNotNull,
      );

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('The FF1 is All Set'), findsOneWidget);
      expect(find.text('Go to Settings'), findsOneWidget);
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNotNull,
      );

      await tester.tap(find.text('Go to Settings'));
      await tester.pumpAndSettle();

      expect(retryingActions.attempts, 2);
      expect(navigatedToConfig, isTrue);
      expect(find.text('DEVICE_CONFIGURATION_MARKER'), findsOneWidget);
      expect(
        container.read(ff1SetupOrchestratorProvider).activeSession,
        isNull,
      );
    },
  );

  testWidgets(
    'portal deeplink does not hide live Bluetooth failure before verified '
    'connect',
    (tester) async {
      final device = BluetoothDevice.fromId('00:11:22:33:44:55');

      const portalDeeplinkInfo = FF1DeviceInfo(
        deviceId: 'FF1-123',
        topicId: 'topic-123',
        isConnectedToInternet: true,
        branchName: 'release',
        version: '1.0.0',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            connectFF1Provider.overrideWith(
              () => _FakeConnectFF1Notifier(ConnectFF1BluetoothOff()),
            ),
            connectWiFiProvider.overrideWith(_IdleWifiNotifier.new),
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
              navigatorKey: appNavigatorKey,
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
                              ff1DeviceInfo: portalDeeplinkInfo,
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

      expect(find.text('The FF1 is All Set'), findsNothing);
      expect(
        find.text(
          'Bluetooth is required for setup. Please turn it on to continue.',
        ),
        findsOneWidget,
      );
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
            connectWiFiProvider.overrideWith(_IdleWifiNotifier.new),
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
              navigatorKey: appNavigatorKey,
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
  // Guided internet-ready completion uses `completeSession` (addDevice,
  // completeOnboarding, hide QR, BLE disconnect, then go to device
  // configuration). Standalone internet-ready (no portal) uses
  // `_completeDirectSuccessExit` (`completeOnboarding` +
  // `tearDownAfterSetupComplete` + replace). Standalone + portal defers exit
  // to Go to Settings. Broader
  // behavior is covered in orchestration/provider tests; this file focuses on
  // Connect UI.
}

/// Wi‑Fi idle so setup derivation does not override connect with Wi‑Fi steps
/// during FF1 connect widget tests.
class _IdleWifiNotifier extends WiFiConnectionNotifier {
  @override
  WiFiConnectionState build() => const WiFiConnectionState();
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
    // Match production: Connecting → Connected so the orchestrator always sees
    // a recognized prior connect state (not Loading→Data with no data prev).
    state = AsyncValue.data(ConnectFF1Connecting(blDevice: bluetoothDevice));
    // Yield so Riverpod and [FF1SetupOrchestratorNotifier.build] can observe
    // Connecting before Connected (mirrors real async connect).
    await Future<void>.value();
    state = AsyncValue.data(_nextState);
  }
}

class _GatedFakeConnectFF1Notifier extends ConnectFF1Notifier {
  _GatedFakeConnectFF1Notifier({
    required this.release,
    required this.nextState,
  });

  final Future<void> release;
  final ConnectFF1State nextState;

  @override
  Future<ConnectFF1State> build() async => ConnectFF1Initial();

  @override
  Future<void> connectBle(
    BluetoothDevice bluetoothDevice, {
    FF1DeviceInfo? ff1DeviceInfo,
  }) async {
    state = AsyncValue.data(ConnectFF1Connecting(blDevice: bluetoothDevice));
    await release;
    state = AsyncValue.data(nextState);
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

class _BlockingFF1BluetoothDeviceActionsNotifier
    extends FF1BluetoothDeviceActionsNotifier {
  _BlockingFF1BluetoothDeviceActionsNotifier(this._completer);

  final Completer<void> _completer;

  @override
  void build() {}

  @override
  Future<void> addDevice(FF1Device device) async {
    await _completer.future;
  }
}

class _FailOnceFF1BluetoothDeviceActionsNotifier
    extends FF1BluetoothDeviceActionsNotifier {
  int attempts = 0;

  @override
  void build() {}

  @override
  Future<void> addDevice(FF1Device device) async {
    attempts++;
    if (attempts == 1) {
      throw StateError('persist failed');
    }
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
        )
        as Future<void>;
  }
}

/// Minimal BLE transport for widget tests (no radio).
class _NoopBleTransport implements FF1BleTransport {
  @override
  BluetoothAdapterState get adapterState => BluetoothAdapterState.on;

  @override
  Stream<BluetoothAdapterState> get adapterStateStream =>
      const Stream<BluetoothAdapterState>.empty();

  @override
  Future<void> connect({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 0,
    bool Function()? shouldContinue,
  }) async {}

  @override
  Future<void> disconnect(BluetoothDevice device) async {}

  @override
  Future<bool> get isSupported async => true;

  @override
  Future<void> scan({
    required FutureOr<bool> Function(List<BluetoothDevice> devices) onDevice,
    Duration timeout = const Duration(seconds: 30),
  }) async {}

  @override
  Future<BluetoothDevice?> scanForName({
    required String name,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return null;
  }

  @override
  Future<FF1BleResponse> sendCommand({
    required BluetoothDevice blDevice,
    required FF1BleCommand command,
    required FF1BleRequest request,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return const FF1BleResponse(topic: 'noop', errorCode: 0, data: <String>[]);
  }

  @override
  Future<void> waitUntilReady({
    required BluetoothDevice blDevice,
    Duration timeout = const Duration(seconds: 20),
  }) async {}
}
