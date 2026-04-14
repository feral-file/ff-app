import 'dart:async';

import 'package:app/app/ff1/ff1_firmware_update_prompt_service.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/version_provider.dart';
import 'package:app/domain/models/ff1/canvas_cast_request_reply.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/api/pubdoc_api.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart'
    as wifi_control;
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/infra/services/version_service.dart';
import 'package:app/ui/screens/device_config_screen.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:app/widgets/device_configuration/options_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/providers/provider_test_helpers.dart';

void main() {
  const updateDescription =
      'Update your FF1 to the latest version. Keep the device connected and '
      'powered on during the update. It will restart automatically when the '
      'update is complete.';

  testWidgets(
    'DeviceConfigScreen Later waits for dismissal to persist before closing',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 12000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dismissalGate = Completer<void>();
      final appState = _BlockingAppStateService(dismissalGate);
      final wifiControl = FakeWifiControl();

      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );
      const deviceStatus = FF1DeviceStatus(
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1DeviceDataProvider.overrideWithValue(
              const FF1DeviceData(
                deviceStatus: null,
                playerStatus: null,
                isConnected: false,
              ),
            ),
            ff1LatestDeviceRealtimeMetricsProvider.overrideWithValue(null),
            ff1DeviceRealtimeMetricsStreamProvider(device.topicId).overrideWith(
              (ref) => const Stream<DeviceRealtimeMetrics>.empty(),
            ),
            ff1CurrentDeviceStatusProvider.overrideWithValue(deviceStatus),
            ff1DeviceConnectedProvider.overrideWithValue(true),
            ff1WifiControlProvider.overrideWithValue(wifiControl),
            ff1FirmwareUpdatePromptServiceProvider.overrideWith(
              (ref) => Ff1FirmwareUpdatePromptService(appState),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DeviceConfigScreen(
                payload: DeviceConfigPayload(isInSetupProcess: false),
              ),
            ),
          ),
        ),
      );

      await _pumpUntilVisible(tester, 'Update Available');

      final laterButton = _primaryAsyncButton('Later');
      final laterAction = tester
          .widget<PrimaryAsyncButton>(laterButton)
          .onTap!();
      await tester.pump();

      expect(appState.calls, 1);
      expect(appState.lastDeviceId, device.deviceId);
      expect(appState.lastVersion, deviceStatus.latestVersion);
      expect(find.text('Update Available'), findsOneWidget);

      dismissalGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsNothing);
      expect(
        appState.dismissedVersions[device.deviceId],
        deviceStatus.latestVersion,
      );
      await laterAction;
    },
  );

  testWidgets(
    'OptionsButton Cancel does not persist a dismissed firmware version',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 12000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final appState = _BlockingAppStateService(Completer<void>());
      final wifiControl = FakeWifiControl();

      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );
      const deviceStatus = FF1DeviceStatus(
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1DeviceDataProvider.overrideWithValue(
              const FF1DeviceData(
                deviceStatus: null,
                playerStatus: null,
                isConnected: false,
              ),
            ),
            ff1LatestDeviceRealtimeMetricsProvider.overrideWithValue(null),
            ff1DeviceRealtimeMetricsStreamProvider(device.topicId).overrideWith(
              (ref) => const Stream<DeviceRealtimeMetrics>.empty(),
            ),
            ff1CurrentDeviceStatusProvider.overrideWithValue(deviceStatus),
            ff1DeviceConnectedProvider.overrideWithValue(true),
            ff1WifiControlProvider.overrideWithValue(wifiControl),
            ff1FirmwareUpdatePromptServiceProvider.overrideWith(
              (ref) => Ff1FirmwareUpdatePromptService(appState),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: OptionsButton()),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SvgPicture));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update FF1').first);
      await tester.pumpAndSettle();

      expect(find.text(updateDescription), findsOneWidget);

      final cancelButton = _primaryAsyncButton('Cancel');
      await tester.widget<PrimaryAsyncButton>(cancelButton).onTap!();
      await tester.pumpAndSettle();

      expect(appState.calls, 0);
      expect(appState.lastDeviceId, isNull);
      expect(appState.lastVersion, isNull);
      expect(
        appState.dismissedVersions[device.deviceId],
        isNull,
      );
      expect(find.text(updateDescription), findsNothing);
    },
  );

  testWidgets(
    'OptionsButton hides Update FF1 until version info is available',
    (tester) async {
      final wifiControl = FakeWifiControl();

      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1DeviceDataProvider.overrideWithValue(
              const FF1DeviceData(
                deviceStatus: null,
                playerStatus: null,
                isConnected: false,
              ),
            ),
            ff1LatestDeviceRealtimeMetricsProvider.overrideWithValue(null),
            ff1DeviceRealtimeMetricsStreamProvider(device.topicId).overrideWith(
              (ref) => const Stream<DeviceRealtimeMetrics>.empty(),
            ),
            ff1CurrentDeviceStatusProvider.overrideWith((ref) => null),
            ff1DeviceConnectedProvider.overrideWithValue(true),
            ff1WifiControlProvider.overrideWithValue(wifiControl),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(child: OptionsButton()),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SvgPicture));
      await tester.pumpAndSettle();

      expect(find.text('Send Log'), findsOneWidget);
      expect(find.text('Update FF1'), findsNothing);
    },
  );

  testWidgets(
    'DeviceConfigScreen ignores blank firmware versions for auto-prompt',
    (tester) async {
      final appState = _BlockingAppStateService(Completer<void>());
      final wifiControl = FakeWifiControl();

      const device = FF1Device(
        name: 'FF1',
        remoteId: 'remote-1',
        deviceId: 'device-1',
        topicId: 'topic-1',
      );
      const deviceStatus = FF1DeviceStatus(
        installedVersion: '   ',
        latestVersion: '2.0.0',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeFF1BluetoothDeviceProvider.overrideWithValue(
              const AsyncData(device),
            ),
            ff1DeviceDataProvider.overrideWithValue(
              const FF1DeviceData(
                deviceStatus: null,
                playerStatus: null,
                isConnected: false,
              ),
            ),
            ff1LatestDeviceRealtimeMetricsProvider.overrideWithValue(null),
            ff1DeviceRealtimeMetricsStreamProvider(device.topicId).overrideWith(
              (ref) => const Stream<DeviceRealtimeMetrics>.empty(),
            ),
            ff1CurrentDeviceStatusProvider.overrideWithValue(deviceStatus),
            ff1DeviceConnectedProvider.overrideWithValue(true),
            ff1WifiControlProvider.overrideWithValue(wifiControl),
            ff1FirmwareUpdatePromptServiceProvider.overrideWith(
              (ref) => Ff1FirmwareUpdatePromptService(appState),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DeviceConfigScreen(
                payload: DeviceConfigPayload(isInSetupProcess: false),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsNothing);
    },
  );

  testWidgets(
    'DeviceConfigScreen does not reuse stale firmware state '
    'after device switch',
    (tester) async {
      await ensureDotEnvLoaded();

      final deviceService = _MutableBluetoothDeviceService();
      final transport = _PromptRaceTransport();
      final wifiControl = wifi_control.FF1WifiControl(transport: transport);
      final appState = _BlockingAppStateService(Completer<void>());
      final versionService = _fakeCompatibleVersionService();

      const deviceA = FF1Device(
        name: 'FF1-A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
      );
      const deviceB = FF1Device(
        name: 'FF1-B',
        remoteId: 'remote-b',
        deviceId: 'device-b',
        topicId: 'topic-b',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          ff1LatestDeviceRealtimeMetricsProvider.overrideWithValue(null),
          ff1DeviceRealtimeMetricsStreamProvider(deviceA.topicId).overrideWith(
            (ref) => const Stream<DeviceRealtimeMetrics>.empty(),
          ),
          ff1DeviceRealtimeMetricsStreamProvider(deviceB.topicId).overrideWith(
            (ref) => const Stream<DeviceRealtimeMetrics>.empty(),
          ),
          ff1FirmwareUpdatePromptServiceProvider.overrideWith(
            (ref) => Ff1FirmwareUpdatePromptService(appState),
          ),
          versionServiceProvider.overrideWithValue(versionService),
        ],
      );
      addTearDown(() async {
        await deviceService.dispose();
        container.dispose();
      });

      container.listen(ff1AutoConnectWatcherProvider, (previous, next) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DeviceConfigScreen(
                payload: DeviceConfigPayload(isInSetupProcess: false),
              ),
            ),
          ),
        ),
      );

      deviceService
        ..devices = [deviceA, deviceB]
        ..activeDeviceId = deviceA.deviceId;
      await container
          .read(
            ff1BluetoothDeviceActionsProvider.notifier,
          )
          .setActiveDevice(deviceA.deviceId);
      await tester.pump();

      transport
        ..emitDeviceConnection(isConnected: true)
        ..emitDeviceStatus(
          installedVersion: '1.0.0',
          latestVersion: '2.0.0',
        );
      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsOneWidget);

      appState.dismissedVersions[deviceA.deviceId] = '2.0.0';
      await container
          .read(
            ff1BluetoothDeviceActionsProvider.notifier,
          )
          .setActiveDevice(deviceB.deviceId);
      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsNothing);

      transport
        ..emitDeviceConnection(isConnected: true)
        ..emitDeviceStatus(
          installedVersion: '1.0.0',
          latestVersion: '2.1.0',
        );
      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsOneWidget);
    },
  );

  testWidgets(
    'DeviceConfigScreen skips prompt when active device changes before show',
    (tester) async {
      await ensureDotEnvLoaded();

      final deviceService = _MutableBluetoothDeviceService();
      final transport = _PromptRaceTransport();
      final wifiControl = wifi_control.FF1WifiControl(transport: transport);
      final appState = _BlockingAppStateService(Completer<void>());
      final versionService = _fakeCompatibleVersionService();

      const deviceA = FF1Device(
        name: 'FF1-A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
      );
      const deviceB = FF1Device(
        name: 'FF1-B',
        remoteId: 'remote-b',
        deviceId: 'device-b',
        topicId: 'topic-b',
      );

      final container = ProviderContainer.test(
        overrides: [
          ff1BluetoothDeviceServiceProvider.overrideWithValue(deviceService),
          ff1WifiControlProvider.overrideWithValue(wifiControl),
          ff1WifiConnectionProvider.overrideWith(
            FF1WifiConnectionNotifier.new,
          ),
          ff1LatestDeviceRealtimeMetricsProvider.overrideWithValue(null),
          ff1DeviceRealtimeMetricsStreamProvider(deviceA.topicId).overrideWith(
            (ref) => const Stream<DeviceRealtimeMetrics>.empty(),
          ),
          ff1DeviceRealtimeMetricsStreamProvider(deviceB.topicId).overrideWith(
            (ref) => const Stream<DeviceRealtimeMetrics>.empty(),
          ),
          ff1FirmwareUpdatePromptServiceProvider.overrideWith(
            (ref) => Ff1FirmwareUpdatePromptService(appState),
          ),
          versionServiceProvider.overrideWithValue(versionService),
        ],
      );
      addTearDown(() async {
        await deviceService.dispose();
        container.dispose();
      });

      container.listen(ff1AutoConnectWatcherProvider, (previous, next) {});

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DeviceConfigScreen(
                payload: DeviceConfigPayload(isInSetupProcess: false),
              ),
            ),
          ),
        ),
      );

      deviceService
        ..devices = [deviceA, deviceB]
        ..activeDeviceId = deviceA.deviceId;
      await container
          .read(
            ff1BluetoothDeviceActionsProvider.notifier,
          )
          .setActiveDevice(deviceA.deviceId);
      await tester.pump();

      transport
        ..emitDeviceConnection(isConnected: true)
        ..emitDeviceStatus(
          installedVersion: '1.0.0',
          latestVersion: '2.0.0',
        );
      await container
          .read(
            ff1BluetoothDeviceActionsProvider.notifier,
          )
          .setActiveDevice(deviceB.deviceId);
      await tester.pumpAndSettle();

      expect(find.text('Update Available'), findsNothing);
    },
  );
}

Future<void> _pumpUntilVisible(WidgetTester tester, String text) async {
  for (var i = 0; i < 20; i++) {
    if (find.text(text).evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for "$text" to appear.');
}

Finder _primaryAsyncButton(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is PrimaryAsyncButton && widget.text == label,
    description: 'PrimaryAsyncButton("$label")',
  );
}

class _BlockingAppStateService implements AppStateService {
  _BlockingAppStateService(this.dismissalGate);

  final Completer<void> dismissalGate;
  final Map<String, String> dismissedVersions = <String, String>{};
  int calls = 0;
  String? lastDeviceId;
  String? lastVersion;

  @override
  String getDismissedUpdateVersion(String deviceId) {
    return dismissedVersions[deviceId] ?? '';
  }

  @override
  Future<void> setDismissedUpdateVersion({
    required String deviceId,
    required String version,
  }) async {
    calls++;
    lastDeviceId = deviceId;
    lastVersion = version;
    await dismissalGate.future;
    dismissedVersions[deviceId] = version;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MutableBluetoothDeviceService implements FF1BluetoothDeviceService {
  final _activeController = StreamController<FF1Device?>.broadcast();

  List<FF1Device> devices = <FF1Device>[];
  String? activeDeviceId;

  @override
  List<FF1Device> getAllDevices() => List<FF1Device>.from(devices);

  @override
  FF1Device? getDeviceById(String deviceId) {
    for (final device in devices) {
      if (device.deviceId == deviceId) return device;
    }
    return null;
  }

  @override
  FF1Device? getActiveDevice() {
    final id = activeDeviceId;
    if (id == null) return null;
    return getDeviceById(id);
  }

  @override
  FF1Device? getDeviceByRemoteId(String remoteId) {
    for (final device in devices) {
      if (device.remoteId == remoteId) return device;
    }
    return null;
  }

  @override
  Future<void> putDevice(FF1Device device) async {
    devices = [
      for (final current in devices)
        if (current.deviceId != device.deviceId) current,
      device,
    ];
  }

  @override
  Future<void> removeDevice(String deviceId) async {
    devices = devices.where((d) => d.deviceId != deviceId).toList();
    if (activeDeviceId == deviceId) {
      activeDeviceId = null;
      _activeController.add(null);
    }
  }

  @override
  Future<void> setActiveDevice(String deviceId) async {
    activeDeviceId = deviceId;
    _activeController.add(getActiveDevice());
  }

  @override
  Future<void> updateConnectionState(String deviceId, int state) async {}

  @override
  Future<void> recordFailedConnection(String deviceId) async {}

  @override
  Future<void> updateTopicId(String deviceId, String topicId) async {}

  @override
  Future<void> updateMetadata(
    String deviceId,
    Map<String, dynamic> metadata,
  ) async {}

  @override
  Stream<List<FF1Device>> watchAllDevices() async* {
    yield getAllDevices();
  }

  @override
  Stream<FF1Device?> watchActiveDevice() async* {
    yield getActiveDevice();
    yield* _activeController.stream;
  }

  Future<void> dispose() async {
    await _activeController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PromptRaceTransport implements FF1WifiTransport {
  _PromptRaceTransport()
    : _notifications = StreamController<FF1NotificationMessage>.broadcast(),
      _connections = StreamController<bool>.broadcast(),
      _errors = StreamController<FF1WifiTransportError>.broadcast();

  final StreamController<FF1NotificationMessage> _notifications;
  final StreamController<bool> _connections;
  final StreamController<FF1WifiTransportError> _errors;

  @override
  Stream<bool> get connectionStateStream => _connections.stream;

  @override
  Stream<FF1NotificationMessage> get notificationStream =>
      _notifications.stream;

  @override
  Stream<FF1WifiTransportError> get errorStream => _errors.stream;

  @override
  bool get isConnected => true;

  @override
  bool get isConnecting => false;

  void emitDeviceStatus({
    required String installedVersion,
    required String latestVersion,
  }) {
    _notifications.add(
      FF1NotificationMessage(
        type: FF1WifiMessageType.notification,
        message: {
          'installedVersion': installedVersion,
          'latestVersion': latestVersion,
        },
        notificationType: FF1NotificationType.deviceStatus,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
  }

  void emitDeviceConnection({required bool isConnected}) {
    _notifications.add(
      FF1NotificationMessage(
        type: FF1WifiMessageType.notification,
        message: {'isConnected': isConnected},
        notificationType: FF1NotificationType.connection,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
  }

  @override
  Future<bool> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
    bool forceReconnect = false,
  }) async {
    return true;
  }

  @override
  void pauseConnection() {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {}

  @override
  void dispose() {
    unawaited(_notifications.close());
    unawaited(_connections.close());
    unawaited(_errors.close());
  }

  @override
  Future<void> disposeFuture() async {
    dispose();
  }
}

VersionService _fakeCompatibleVersionService() {
  return VersionService(
    pubDocApi: PubDocApiImpl(),
    platformOverride: 'ios',
    packageInfoLoader: () async => PackageInfo(
      appName: 'app',
      packageName: 'pkg',
      version: '10.0.0',
      buildNumber: '1',
    ),
  );
}
