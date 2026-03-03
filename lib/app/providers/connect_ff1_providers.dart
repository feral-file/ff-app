import 'dart:async';

import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/extensions/string_ext.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/domain/models/models.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final _log = Logger('ConnectFF1Notifier');

/// State for the connect FF1 BLE flow
sealed class ConnectFF1State {
  const ConnectFF1State();
}

/// Initial state
class ConnectFF1Initial extends ConnectFF1State {}

/// BLE connecting state
class ConnectFF1Connecting extends ConnectFF1State {
  /// Constructor
  const ConnectFF1Connecting({required this.blDevice});

  /// Bluetooth device being connected to
  final BluetoothDevice blDevice;
}

/// BLE still connecting state (after 15 seconds)
class ConnectFF1StillConnecting extends ConnectFF1State {
  /// Constructor
  const ConnectFF1StillConnecting({required this.blDevice});

  /// Bluetooth device being connected to
  final BluetoothDevice blDevice;
}

/// BLE connected state
class ConnectFF1Connected extends ConnectFF1State {
  /// Constructor
  const ConnectFF1Connected({
    required this.ff1device,
    required this.portalIsSet,
    required this.isConnectedToInternet,
  });

  /// FF1 device
  final FF1Device ff1device;

  /// Whether the portal is set
  final bool portalIsSet;

  /// Whether the device is connected to internet
  final bool isConnectedToInternet;
}

/// Error state
class ConnectFF1Error extends ConnectFF1State {
  /// Constructor
  const ConnectFF1Error({required this.exception});

  /// Error
  final Exception exception;
}

/// Connect FF1 providers
class ConnectFF1Notifier extends AsyncNotifier<ConnectFF1State> {
  Timer? _stillConnectingTimer;
  bool _cancelRequested = false;

  @override
  Future<ConnectFF1State> build() async {
    return ConnectFF1Initial();
  }

  /// Connect to device via BLE
  ///
  /// Takes a [BluetoothDevice] and connects to it.
  /// Updates state to [ConnectFF1Connecting], then [ConnectFF1StillConnecting]
  /// after 15 seconds, and finally [ConnectFF1Connected] on success.
  Future<void> connectBle(
    BluetoothDevice bluetoothDevice, {
    FF1DeviceInfo? ff1DeviceInfo,
  }) async {
    _cancelRequested = false;
    _stillConnectingTimer?.cancel();

    // Set initial connecting state
    state = AsyncValue.data(ConnectFF1Connecting(blDevice: bluetoothDevice));

    // Set up timer for "still connecting" state after 15 seconds
    _stillConnectingTimer = Timer(
      const Duration(seconds: 15),
      () {
        if (!_cancelRequested && state.value is ConnectFF1Connecting) {
          state = AsyncValue.data(
            ConnectFF1StillConnecting(
              blDevice: bluetoothDevice,
            ),
          );
        }
      },
    );

    try {
      final control = ref.read(ff1ControlProvider);
      var blDevice = bluetoothDevice;
      if (blDevice.remoteId.str.isEmpty) {
        if (ff1DeviceInfo == null) {
          throw Exception('Device info is not provided');
        }

        _log.info(
          '[ConnectFF1Notifier] Device ${ff1DeviceInfo.name} has empty '
          'remoteID, scan and connect',
        );
        final foundDevice = await control.scanForName(
          name: ff1DeviceInfo.name,
        );
        if (foundDevice != null) {
          blDevice = foundDevice;
        }
      }

      await control.connect(blDevice: blDevice);
      await _handlePostConnect(ff1DeviceInfo, blDevice);
    } on FF1ConnectionCancelledError catch (_) {
      _log.info('[ConnectFF1Notifier] Connection cancelled by user');
    } on Exception catch (e) {
      _log.info('[ConnectFF1Notifier] Error connecting to device: $e');
      state = AsyncValue.data(ConnectFF1Error(exception: e));
    }

    _log.info('[ConnectFF1Notifier] Successfully connected to device');

    // Cancel timer if connection succeeded before 15 seconds
    _stillConnectingTimer?.cancel();
  }

  Future<void> _handlePostConnect(
    FF1DeviceInfo? initialFF1DeviceInfo,
    BluetoothDevice blDevice,
  ) async {
    var ff1DeviceInfo = initialFF1DeviceInfo;
    // If device info is not provided, fetch it via get_info command
    if (ff1DeviceInfo == null) {
      _log.info(
        '[ConnectFF1Notifier] Device info not provided, fetching via get_info',
      );
      try {
        // Add delay to ensure connection is stable and characteristics are discovered
        // Connection state handler already waits 1s, but add extra delay for getInfo
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final control = ref.read(ff1ControlProvider);
        final getInfoResponse = await control.getInfo(blDevice: blDevice);
        ff1DeviceInfo = getInfoResponse.toFF1DeviceInfo;

        _log.info(
          '[ConnectFF1Page] Got device info: topicId=${ff1DeviceInfo.topicId}, '
          'isConnectedToInternet=${ff1DeviceInfo.isConnectedToInternet}, '
          'branchName=${ff1DeviceInfo.branchName}, version=${ff1DeviceInfo.version}',
        );

        // TODO: Check version compatibility
        // // Check version compatibility
        // final compatible =
        //     await injector<VersionService>().checkDeviceVersionCompatibility(
        //   dBranch: ff1Device.branchName,
        //   dVersion: ff1Device.version,
        //   requiredDeviceUpdate: false,
        // );

        // if (compatible == VersionCompatibilityResult.needUpdateApp) {
        //   _log.info(
        //     'FF1 version is not compatible with the app. Please update the app.',
        //   );
        //   return;
        // }
      } on Exception catch (e) {
        _log.warning('[ConnectFF1Page] Failed to get device info: $e');
        rethrow;
      }
    }

    var ff1Device = FF1Device.fromBluetoothDeviceAndDeviceInfo(
      blDevice,
      ff1DeviceInfo,
    );

    if (!ff1DeviceInfo.isConnectedToInternet) {
      state = AsyncValue.data(
        ConnectFF1Connected(
          ff1device: ff1Device,
          portalIsSet: false,
          isConnectedToInternet: false,
        ),
      );
      return;
    }

    final topicId = ff1Device.topicId;
    if (topicId.isNotEmpty) {
      // Hide QR code on device
      await ref
          .read(ff1WifiControlProvider)
          .showPairingQRCode(topicId: topicId, show: false);

      // Show portal is set
      state = AsyncValue.data(
        ConnectFF1Connected(
          ff1device: ff1Device,
          portalIsSet: true,
          isConnectedToInternet: true,
        ),
      );
      return;
    }

    final topicIdFromKeepWifi = await ref
        .read(ff1ControlProvider)
        .keepWifi(blDevice: blDevice);
    if (topicIdFromKeepWifi.isEmpty) {
      throw Exception('Failed to get topicId from keepWifi');
    }

    ff1Device = ff1Device.copyWith(topicId: topicIdFromKeepWifi);
    state = AsyncValue.data(
      ConnectFF1Connected(
        ff1device: ff1Device,
        portalIsSet: false,
        isConnectedToInternet: true,
      ),
    );
  }

  /// Cancel the current connection attempt
  void cancelConnection() {
    _cancelRequested = true;
    _stillConnectingTimer?.cancel();
  }

  /// Reset to initial state
  void reset() {
    _cancelRequested = false;
    _stillConnectingTimer?.cancel();
    state = AsyncValue.data(ConnectFF1Initial());
  }
}

/// Provider for connect FF1 flow
final connectFF1Provider =
    AsyncNotifierProvider<ConnectFF1Notifier, ConnectFF1State>(
      ConnectFF1Notifier.new,
    );
