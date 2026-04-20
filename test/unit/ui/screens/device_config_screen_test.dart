import 'dart:async';

import 'package:app/app/ff1/ff1_firmware_update_prompt_service.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/indexer/sync_collection.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/ui/screens/device_config_screen.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:app/widgets/device_configuration/ffp_status_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/legacy.dart';
import 'package:riverpod/misc.dart' show Override;

void main() {
  testWidgets(
    'shows FFP monitor controls during setup once relayer status arrives',
    (tester) async {
      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: true,
          deviceData: const FF1DeviceData(
            deviceStatus: FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
            playerStatus: null,
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
          ),
          currentPlayerStatus: null,
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.on,
            monitor: 'Test Monitor',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('FFP Status'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('FFP Status'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ffp_brightness_slider')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FfpStatusSection),
          matching: find.byType(IconButton),
        ),
        findsWidgets,
        reason:
            'The setup flow should still expose monitor power controls when '
            'the relayer has status for the display.',
      );
    },
  );

  testWidgets(
    'keeps monitor power controls visible when the player is sleeping',
    (tester) async {
      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: false,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: true,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
          ),
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: true,
          ),
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.off,
            monitor: 'Test Monitor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rotateButton = tester.widget<PrimaryAsyncButton>(
        find.ancestor(
          of: find.text('Rotate'),
          matching: find.byType(PrimaryAsyncButton),
        ),
      );
      expect(
        rotateButton.enabled,
        isFalse,
        reason:
            'Legacy FF1 actions stay disabled while sleeping; DDC uses its own '
            'gate.',
      );

      await tester.dragUntilVisible(
        find.text('FFP Status'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('FFP Status'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FfpStatusSection),
          matching: find.byType(IconButton),
        ),
        findsWidgets,
        reason:
            'Sleeping/off should not hide the monitor power buttons because '
            'users need them to wake the display.',
      );
    },
  );

  testWidgets(
    'renders FFP status between device information and performance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 5000));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: false,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: false,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
          ),
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: false,
          ),
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.off,
            monitor: 'Test Monitor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final deviceInfoTop = tester.getTopLeft(
        find.text('Device Information'),
      );
      final ffpStatusTop = tester.getTopLeft(find.text('FFP Status'));
      final performanceTop = tester.getTopLeft(
        find.text('Performance Monitoring'),
      );

      expect(
        deviceInfoTop.dy < ffpStatusTop.dy,
        isTrue,
        reason: 'FFP Status should render after Device Information.',
      );
      expect(
        ffpStatusTop.dy < performanceTop.dy,
        isTrue,
        reason: 'FFP Status should render before Performance Monitoring.',
      );
      expect(
        find.byKey(
          const ValueKey('ffp_status_to_performance_divider'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'pairing QR button shows Hide when displayUrl has step=qrcode',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: false,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
              displayUrl: 'https://example.com/?step=qrcode',
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: false,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
            displayUrl: 'https://example.com/?step=qrcode',
          ),
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: false,
          ),
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.on,
            monitor: 'Test Monitor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Device Information'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hide QR Code'), findsOneWidget);
    },
  );

  testWidgets(
    'pairing QR button shows Show when displayUrl is not qrcode step',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: false,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
              displayUrl: 'https://example.com/?step=home',
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: false,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
            displayUrl: 'https://example.com/?step=home',
          ),
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: false,
          ),
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.on,
            monitor: 'Test Monitor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Device Information'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show Pairing QR Code'), findsOneWidget);
    },
  );

  testWidgets(
    'pairing QR button defaults to Hide when displayUrl is absent '
    'outside setup',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: false,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: false,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
          ),
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: false,
          ),
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.on,
            monitor: 'Test Monitor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Device Information'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hide QR Code'), findsOneWidget);
    },
  );

  testWidgets(
    'pairing QR button is hidden during setup flow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: true,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
              displayUrl: 'https://example.com/?step=qrcode',
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: false,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
            displayUrl: 'https://example.com/?step=qrcode',
          ),
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: false,
          ),
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.on,
            monitor: 'Test Monitor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hide QR Code'), findsNothing);
      expect(find.text('Show Pairing QR Code'), findsNothing);
    },
  );

  testWidgets(
    'pairing QR button stays hidden during setup when displayUrl is absent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: true,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: false,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
          ),
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: false,
          ),
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.on,
            monitor: 'Test Monitor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hide QR Code'), findsNothing);
      expect(find.text('Show Pairing QR Code'), findsNothing);
    },
  );

  testWidgets(
    'pairing QR button keeps local state after successful in-flight toggle',
    (tester) async {
      final currentStatusProvider = StateProvider<FF1DeviceStatus?>(
        (ref) => const FF1DeviceStatus(
          volume: 40,
          isMuted: false,
          displayUrl: 'https://example.com/?step=qrcode',
        ),
      );
      final toggleCompleter = Completer<FF1CommandResponse>();

      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: false,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
              displayUrl: 'https://example.com/?step=qrcode',
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: false,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: null,
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: false,
          ),
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.on,
            monitor: 'Test Monitor',
          ),
          currentDeviceStatusStateProvider: currentStatusProvider,
          wifiControl: _ControllableWifiControl(
            onShowPairingQRCode: ({required topicId, required show}) =>
                toggleCompleter.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Device Information'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hide QR Code'), findsOneWidget);

      await tester.tap(find.text('Hide QR Code'));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeviceConfigScreen)),
      );
      container
          .read(currentStatusProvider.notifier)
          .state = const FF1DeviceStatus(
        volume: 40,
        isMuted: false,
        displayUrl: 'https://example.com/?step=home',
      );
      await tester.pump();
      container
          .read(currentStatusProvider.notifier)
          .state = const FF1DeviceStatus(
        volume: 40,
        isMuted: false,
        displayUrl: 'https://example.com/?step=qrcode',
      );
      await tester.pump();

      toggleCompleter.complete(FF1CommandResponse(status: 'ok'));
      await tester.pumpAndSettle();

      expect(find.text('Show Pairing QR Code'), findsOneWidget);
    },
  );

  testWidgets(
    'pairing QR toggle ignores stale success after switching active device',
    (tester) async {
      const deviceA = FF1Device(
        name: 'FF1 A',
        remoteId: 'remote-a',
        deviceId: 'device-a',
        topicId: 'topic-a',
      );
      const deviceB = FF1Device(
        name: 'FF1 B',
        remoteId: 'remote-b',
        deviceId: 'device-b',
        topicId: 'topic-b',
      );
      final activeDeviceProvider = StateProvider<FF1Device>((ref) => deviceA);

      final currentStatusProvider = StateProvider<FF1DeviceStatus?>(
        (ref) => const FF1DeviceStatus(
          volume: 40,
          isMuted: false,
          displayUrl: 'https://example.com/?step=qrcode',
        ),
      );
      final toggleCompleter = Completer<FF1CommandResponse>();

      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: false,
          activeDeviceOverride: deviceA,
          dynamicActiveFf1DeviceProvider: activeDeviceProvider,
          extraFfpPanelTopicIds: {deviceB.topicId},
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
              displayUrl: 'https://example.com/?step=qrcode',
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: false,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: null,
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: false,
          ),
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.on,
            monitor: 'Test Monitor',
          ),
          currentDeviceStatusStateProvider: currentStatusProvider,
          wifiControl: _ControllableWifiControl(
            onShowPairingQRCode: ({required topicId, required show}) =>
                toggleCompleter.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Device Information'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hide QR Code'), findsOneWidget);

      await tester.tap(find.text('Hide QR Code'));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeviceConfigScreen)),
      );
      container.read(activeDeviceProvider.notifier).state = deviceB;
      await tester.pump();

      toggleCompleter.complete(FF1CommandResponse(status: 'ok'));
      await tester.pumpAndSettle();
      // Flush debounced listeners (e.g. FF1 UI helpers) before test end.
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text('Hide QR Code'),
        findsOneWidget,
        reason:
            'Success for the previous device must not flip the shared toggle '
            'label after the active device changes.',
      );
    },
  );

  testWidgets(
    'pairing QR button reconciles skipped status after failed in-flight toggle',
    (tester) async {
      final currentStatusProvider = StateProvider<FF1DeviceStatus?>(
        (ref) => const FF1DeviceStatus(
          volume: 40,
          isMuted: false,
          displayUrl: 'https://example.com/?step=qrcode',
        ),
      );
      final toggleCompleter = Completer<FF1CommandResponse>();

      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: false,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
              displayUrl: 'https://example.com/?step=qrcode',
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: false,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: null,
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: false,
          ),
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.on,
            monitor: 'Test Monitor',
          ),
          currentDeviceStatusStateProvider: currentStatusProvider,
          wifiControl: _ControllableWifiControl(
            onShowPairingQRCode: ({required topicId, required show}) =>
                toggleCompleter.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Device Information'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hide QR Code'), findsOneWidget);

      await tester.tap(find.text('Hide QR Code'));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DeviceConfigScreen)),
      );
      container
          .read(currentStatusProvider.notifier)
          .state = const FF1DeviceStatus(
        volume: 40,
        isMuted: false,
        displayUrl: 'https://example.com/?step=home',
      );
      await tester.pump();

      toggleCompleter.complete(
        FF1CommandResponse(
          status: 'ok',
          data: const {'ok': false},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Show Pairing QR Code'), findsOneWidget);
    },
  );

  testWidgets(
    'hides the divider before performance when FFP status is hidden',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 5000));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: false,
          deviceData: FF1DeviceData(
            deviceStatus: const FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
            playerStatus: FF1PlayerStatus(
              playlistId: 'playlist-1',
              sleepMode: false,
            ),
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
          ),
          currentPlayerStatus: FF1PlayerStatus(
            playlistId: 'playlist-1',
            sleepMode: false,
          ),
          panelStatus: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('ffp_status_to_performance_divider'),
        ),
        findsNothing,
        reason:
            'When FFP Status is hidden, the screen should not insert the extra '
            'divider before Performance Monitoring.',
      );
    },
  );

  testWidgets(
    'allows FFP DDC controls when device status is missing but relayer has DDC',
    (tester) async {
      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: false,
          deviceData: const FF1DeviceData(
            deviceStatus: null,
            playerStatus: null,
            isConnected: true,
          ),
          currentDeviceStatus: null,
          currentPlayerStatus: null,
          panelStatus: const FfpDdcPanelStatus(
            brightness: 25,
            contrast: 60,
            power: FfpDdcPanelPower.on,
            monitor: 'Test Monitor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rotateButton = tester.widget<PrimaryAsyncButton>(
        find.ancestor(
          of: find.text('Rotate'),
          matching: find.byType(PrimaryAsyncButton),
        ),
      );
      expect(rotateButton.enabled, isFalse);

      await tester.dragUntilVisible(
        find.text('FFP Status'),
        find.byType(CustomScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('ffp_brightness_slider')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'hides the monitor section until relayer status is available',
    (tester) async {
      await tester.pumpWidget(
        _wrapScreen(
          isInSetupProcess: true,
          deviceData: const FF1DeviceData(
            deviceStatus: FF1DeviceStatus(
              volume: 40,
              isMuted: false,
            ),
            playerStatus: null,
            isConnected: true,
          ),
          currentDeviceStatus: const FF1DeviceStatus(
            volume: 40,
            isMuted: false,
          ),
          currentPlayerStatus: null,
          panelStatus: null,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FFP Status'), findsNothing);
      expect(find.byKey(const ValueKey('ffp_brightness_slider')), findsNothing);
    },
  );
}

List<Override> _deviceConfigScreenOverrides({
  required FF1Device activeDevice,
  required FF1DeviceData deviceData,
  required FF1DeviceStatus? currentDeviceStatus,
  required FF1PlayerStatus? currentPlayerStatus,
  required FfpDdcPanelStatus? panelStatus,
  StateProvider<FF1DeviceStatus?>? currentDeviceStatusStateProvider,
  FF1WifiControl? wifiControl,
  StateProvider<FF1Device>? dynamicActiveFf1DeviceProvider,
  Set<String>? extraFfpPanelTopicIds,
}) {
  final ffpOverrides = <Override>[];
  final topicIds = <String>{
    activeDevice.topicId,
    ...?extraFfpPanelTopicIds,
  };
  for (final topicId in topicIds) {
    ffpOverrides.add(
      panelStatus != null
          ? ff1FfpDdcPanelStatusStreamProvider(
              topicId,
            ).overrideWithValue(AsyncData(panelStatus))
          : ff1FfpDdcPanelStatusStreamProvider(
              topicId,
            ).overrideWithValue(const AsyncLoading<FfpDdcPanelStatus>()),
    );
  }

  return [
    ?dynamicActiveFf1DeviceProvider,
    activeFF1BluetoothDeviceProvider.overrideWith((ref) {
      final resolved = dynamicActiveFf1DeviceProvider != null
          ? ref.watch(dynamicActiveFf1DeviceProvider)
          : activeDevice;
      return Stream<FF1Device?>.value(resolved);
    }),
    ff1WifiControlProvider.overrideWithValue(
      wifiControl ?? _FakeWifiControl(),
    ),
    ff1DeviceDataProvider.overrideWithValue(deviceData),
    if (currentDeviceStatusStateProvider != null)
      ff1CurrentDeviceStatusProvider.overrideWith(
        (ref) => ref.watch(currentDeviceStatusStateProvider),
      )
    else
      ff1CurrentDeviceStatusProvider.overrideWithValue(currentDeviceStatus),
    ff1CurrentPlayerStatusProvider.overrideWithValue(currentPlayerStatus),
    ff1DeviceConnectedProvider.overrideWithValue(false),
    ff1FirmwareUpdatePromptServiceProvider.overrideWith(
      (ref) => Ff1FirmwareUpdatePromptService(_NoopPromptStateService()),
    ),
    ...ffpOverrides,
  ];
}

Widget _wrapScreen({
  required bool isInSetupProcess,
  required FF1DeviceData deviceData,
  required FF1DeviceStatus? currentDeviceStatus,
  required FF1PlayerStatus? currentPlayerStatus,
  required FfpDdcPanelStatus? panelStatus,
  StateProvider<FF1DeviceStatus?>? currentDeviceStatusStateProvider,
  FF1WifiControl? wifiControl,
  FF1Device? activeDeviceOverride,
  StateProvider<FF1Device>? dynamicActiveFf1DeviceProvider,
  Set<String>? extraFfpPanelTopicIds,
}) {
  final effectiveDevice = activeDeviceOverride ?? device;
  return ProviderScope(
    overrides: _deviceConfigScreenOverrides(
      activeDevice: effectiveDevice,
      deviceData: deviceData,
      currentDeviceStatus: currentDeviceStatus,
      currentPlayerStatus: currentPlayerStatus,
      panelStatus: panelStatus,
      currentDeviceStatusStateProvider: currentDeviceStatusStateProvider,
      wifiControl: wifiControl,
      dynamicActiveFf1DeviceProvider: dynamicActiveFf1DeviceProvider,
      extraFfpPanelTopicIds: extraFfpPanelTopicIds,
    ),
    child: MaterialApp(
      home: DeviceConfigScreen(
        payload: DeviceConfigPayload(isInSetupProcess: isInSetupProcess),
      ),
    ),
  );
}

const device = FF1Device(
  name: 'FF1 Test',
  remoteId: 'remote-id',
  deviceId: 'device-id',
  topicId: 'topic-1',
);

class _FakeWifiControl extends FF1WifiControl {
  _FakeWifiControl()
    : super(
        transport: _FakeWifiTransport(),
        restClient: null,
      );
}

class _ControllableWifiControl extends _FakeWifiControl {
  _ControllableWifiControl({
    required this.onShowPairingQRCode,
  });

  final Future<FF1CommandResponse> Function({
    required String topicId,
    required bool show,
  })
  onShowPairingQRCode;

  @override
  Future<FF1CommandResponse> showPairingQRCode({
    required String topicId,
    required bool show,
  }) {
    return onShowPairingQRCode(topicId: topicId, show: show);
  }
}

class _FakeWifiTransport implements FF1WifiTransport {
  @override
  Stream<bool> get connectionStateStream => const Stream<bool>.empty();

  @override
  Stream<FF1WifiTransportError> get errorStream =>
      const Stream<FF1WifiTransportError>.empty();

  @override
  bool get isConnected => true;

  @override
  bool get isConnecting => false;

  @override
  Stream<FF1NotificationMessage> get notificationStream =>
      const Stream<FF1NotificationMessage>.empty();

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
  void dispose() {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> disposeFuture() async {}

  @override
  void pauseConnection() {}

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {}
}

class _NoopPromptStateService implements AppStateServiceBase {
  @override
  Future<bool> hasSeenOnboarding() async => false;

  @override
  Future<void> setHasSeenOnboarding({required bool hasSeen}) async {}

  @override
  Future<bool> hasSeenPlayToFf1Tooltip() async => false;

  @override
  Future<void> setHasSeenPlayToFf1Tooltip({required bool hasSeen}) async {}

  @override
  Future<bool> hasCompletedSeedDownload() async => false;

  @override
  Future<void> setHasCompletedSeedDownload({required bool completed}) async {}

  @override
  String getDismissedUpdateVersion(String deviceId) => '';

  @override
  Future<void> setDismissedUpdateVersion({
    required String deviceId,
    required String version,
  }) async {}

  @override
  Future<SyncCheckpoint?> getAddressCheckpoint(String address) async => null;

  @override
  Future<void> setAddressCheckpoint({
    required String address,
    required SyncCheckpoint checkpoint,
  }) async {}

  @override
  Future<void> clearAddressCheckpoint(String address) async {}

  @override
  Future<List<String>> getAddressesWithCompletedIndexing() async => [];

  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) => const Stream<AddressIndexingProcessStatus?>.empty();

  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {}

  @override
  Future<void> addTrackedAddress(String address, {String alias = ''}) async {}

  @override
  Future<void> clearAddressState(String address) async {}

  @override
  Future<Map<String, AddressIndexingProcessStatus>>
  getAllAddressIndexingStatuses() async => {};

  @override
  Future<void> trackPersonalAddress(String address) async {}

  @override
  Future<List<String>> getTrackedPersonalAddresses() async => [];

  @override
  Future<List<WalletAddress>> getTrackedWalletAddresses() async => [];
}
