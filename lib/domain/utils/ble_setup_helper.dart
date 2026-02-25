import 'dart:async';

import 'package:app/app/routing/navigation_extensions.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/pair.dart';
import 'package:app/domain/models/wifi_point.dart';
import 'package:app/ui/screens/ff1_setup/connect_ff1_page.dart';
import 'package:app/ui/screens/scan_wifi_network_screen.dart';
import 'package:app/ui/screens/send_wifi_credentials_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

final _log = Logger('BLESetupHelper');

/// Helper class to handle BLE-based FF1 setup flow.
/// Replaces QR-based setup with BLE discovery.
class BLESetupHelper {
  /// Handle BLE-discovered device setup.
  static Future<void> handleBLEDeviceSetup(
    BluetoothDevice device,
    BuildContext context,
  ) async {
    _log.info(
      '[BLESetupHelper] Handling BLE device setup for: ${device.advName}',
    );

    // Navigate to connect page
    // Device info will be fetched via get_info command after connection
    await context.push(
      Routes.connectFF1Page,
      extra: ConnectFF1PagePayload(
        device: device,
        // onConnectedSuccess: (ff1Device) async {
        //   await _proceedWithWifiSetup(context, device, ff1Device);
        // },
      ),
    );
  }

  static Future<void> _proceedWithWifiSetup(
    BuildContext context,
    BluetoothDevice device,
    FF1Device ff1Device,
  ) async {
    await context.push(
      Routes.scanWifiNetworks,
      extra: ScanWifiNetworkPagePayload(
        device: ff1Device,
        // onNetworkSelected: (accessPoint) async {
        //   await _onWifiSelected(
        //     context,
        //     accessPoint,
        //     ff1Device,
        //   );
        // },
      ),
    );

    await device.disconnect();
  }

  static Future<void> _onWifiSelected(
    BuildContext context,
    WifiPoint accessPoint,
    FF1Device ff1Device,
  ) async {
    _log.info('[BLESetupHelper] onWifiSelected: $accessPoint');
    final payload = EnterWifiPasswordPagePayload(
      wifiAccessPoint: accessPoint,
      device: ff1Device,
      onSubmitted: (String? topicId, Object? error) async {
        final res = topicId != null ? Pair(topicId, true) : null;
        if (res != null) {
          // ff1Device.copyWith(topicId: res.first);

          // final deviceService = ref.read(ff1BluetoothDeviceServiceProvider);

          // await deviceService.putDevice(ff1Device);
          // _log.info('Device updated in database with topicId: $topicId');

          // // Set as active device
          // await deviceService.setActiveDevice(ff1Device.deviceId);
          // _log.info('Device set as active');

          // // Update connection state to connected
          // await deviceService.updateConnectionState(ff1Device.deviceId, 1);

          // Invalidate providers to reflect changes
          // ref.invalidate(allFF1BluetoothDevicesProvider);
          // ref.invalidate(activeFF1BluetoothDeviceProvider);
          // ref.invalidate(ff1BluetoothDeviceByIdProvider(ff1Device.deviceId));

          // // Hide QR code on device
          // await ref
          //     .read(ff1WifiControlProvider)
          //     .showPairingQRCode(topicId: topicId, show: false);

          if (context.mounted) {
            context.popUntil(Routes.startSetupFf1);
            // context.push(Routes.deviceConfiguration,
            //     extra: DeviceConfigPayload(
            //         isFromOnboarding: true));
          }
        } else if (error != null) {
          if (context.mounted) {
            context
              ..popUntil(Routes.startSetupFf1)
              ..pop();
          }
        }
      },
    );
    await context.push(Routes.enterWifiPassword, extra: payload);
  }
}
