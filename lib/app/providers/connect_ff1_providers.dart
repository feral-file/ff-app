import 'dart:async';

import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/version_provider.dart';
import 'package:app/domain/extensions/string_ext.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/services/version_service.dart';
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

/// Bluetooth is off — waiting for the user to enable it
class ConnectFF1BluetoothOff extends ConnectFF1State {}

/// Error state
class ConnectFF1Error extends ConnectFF1State {
  /// Constructor
  const ConnectFF1Error({required this.exception});

  /// Error
  final Exception exception;
}

/// Connect FF1 providers
class ConnectFF1Notifier extends AsyncNotifier<ConnectFF1State> {
  static const List<Duration> _getInfoRetryDelays = [
    Duration(milliseconds: 300),
    Duration(milliseconds: 900),
    Duration(milliseconds: 1500),
    Duration(milliseconds: 2200),
  ];

  static const Duration _getInfoReadinessTimeout = Duration(seconds: 8);

  Timer? _stillConnectingTimer;
  bool _cancelRequested = false;

  // Completer used while waiting for Bluetooth to turn on.
  // Completed normally when BT becomes ready; completed with
  // [FF1ConnectionCancelledError] when [cancelConnection] is called.
  Completer<void>? _btReadyCompleter;

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

    final control = ref.read(ff1ControlProvider);
    var blDevice = bluetoothDevice;

    // For the deeplink flow (no device ID), we need to scan via BLE.
    // Check Bluetooth state BEFORE emitting any connecting state so the UI
    // never flashes "Connecting…" when BT is already off.
    if (blDevice.remoteId.str.isEmpty) {
      if (ff1DeviceInfo == null) {
        state = AsyncValue.data(
          ConnectFF1Error(exception: Exception('Device info is not provided')),
        );
        return;
      }

      if (control.currentAdapterState != BluetoothAdapterState.on) {
        _log.info('[ConnectFF1Notifier] BT adapter off, waiting for it');
        state = AsyncValue.data(ConnectFF1BluetoothOff());
        try {
          await _waitForBtReady(control);
        } on FF1ConnectionCancelledError catch (_) {
          _log.info('[ConnectFF1Notifier] Cancelled while waiting for BT');
          return;
        }
      }
    }

    // BT is ready (or not required for direct-device flow).
    // Now it is safe to show the connecting state and start the timer.
    state = AsyncValue.data(ConnectFF1Connecting(blDevice: bluetoothDevice));

    _stillConnectingTimer = Timer(
      const Duration(seconds: 15),
      () {
        if (!_cancelRequested && state.value is ConnectFF1Connecting) {
          state = AsyncValue.data(
            ConnectFF1StillConnecting(blDevice: bluetoothDevice),
          );
        }
      },
    );

    try {
      if (blDevice.remoteId.str.isEmpty) {
        _log.info(
          '[ConnectFF1Notifier] Scanning for ${ff1DeviceInfo!.name}',
        );
        final foundDevice = await control.scanForName(
          name: ff1DeviceInfo.name,
        );
        if (foundDevice == null) {
          throw Exception(
            'FF1 device "${ff1DeviceInfo.name}" not found. '
            'Make sure it is powered on and nearby.',
          );
        }
        blDevice = foundDevice;
      }

      await control.connect(blDevice: blDevice);
      await _handlePostConnect(ff1DeviceInfo, blDevice);
      _log.info('[ConnectFF1Notifier] Successfully connected to device');
    } on FF1ConnectionCancelledError catch (_) {
      _log.info('[ConnectFF1Notifier] Connection cancelled by user');
    } on Exception catch (e) {
      _log.info('[ConnectFF1Notifier] Error connecting to device: $e');
      state = AsyncValue.data(ConnectFF1Error(exception: e));
    }

    _log.info('[ConnectFF1Notifier] connectBle completed');
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
        final getInfoResponse = await _getInfoWithRetry(blDevice);
        ff1DeviceInfo = getInfoResponse.toFF1DeviceInfo;

        _log.info(
          '[ConnectFF1Page] Got device info: '
          'topicId=${ff1DeviceInfo.topicId}, '
          'internet=${ff1DeviceInfo.isConnectedToInternet}, '
          'branch=${ff1DeviceInfo.branchName}, '
          'version=${ff1DeviceInfo.version}',
        );
      } on Exception catch (e) {
        _log.warning('[ConnectFF1Page] Failed to get device info: $e');
        rethrow;
      }
    }

    // Check version compatibility
    final versionService = ref.read(versionServiceProvider);
    final compatibility = await versionService.checkDeviceVersionCompatibility(
      branchName: ff1DeviceInfo.branchName,
      deviceVersion: ff1DeviceInfo.version,
    );

    if (compatibility == VersionCompatibilityResult.needUpdateApp) {
      _log.info(
        '[ConnectFF1Notifier] App update required for device '
        '${ff1DeviceInfo.deviceId}.',
      );
      return;
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

  Future<String> _getInfoWithRetry(BluetoothDevice blDevice) async {
    final control = ref.read(ff1ControlProvider);

    Exception? lastError;
    for (final delay in _getInfoRetryDelays) {
      await Future<void>.delayed(delay);
      try {
        await control.waitUntilReady(
          blDevice: blDevice,
          timeout: _getInfoReadinessTimeout,
        );
        return await control.getInfo(blDevice: blDevice);
      } on Exception catch (e) {
        lastError = e;
        final shouldRetry =
            e is TimeoutException ||
            e.toString().contains('BLE characteristic readiness timeout') ||
            e.toString().contains('Command characteristic not found');
        if (!shouldRetry) {
          rethrow;
        }
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    throw Exception('Failed to get device info');
  }

  /// Wait until Bluetooth adapter is [BluetoothAdapterState.on].
  ///
  /// Subscribes to [FF1BleControl.adapterStateStream] and completes when the
  /// adapter becomes ready.  If [cancelConnection] is called while waiting,
  /// the completer is rejected with [FF1ConnectionCancelledError] so that
  /// [connectBle] exits cleanly.
  Future<void> _waitForBtReady(FF1BleControl control) async {
    _btReadyCompleter = Completer<void>();

    final sub = control.adapterStateStream.listen((s) {
      if (s == BluetoothAdapterState.on &&
          !(_btReadyCompleter?.isCompleted ?? true)) {
        _btReadyCompleter?.complete();
      }
    });

    try {
      await _btReadyCompleter!.future;
    } finally {
      unawaited(sub.cancel());
      _btReadyCompleter = null;
    }
  }

  /// Cancel the current connection attempt
  void cancelConnection() {
    _cancelRequested = true;
    _stillConnectingTimer?.cancel();
    if (!(_btReadyCompleter?.isCompleted ?? true)) {
      _btReadyCompleter?.completeError(const FF1ConnectionCancelledError());
    }
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
