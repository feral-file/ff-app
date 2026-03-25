import 'dart:async';

import 'package:app/app/ff1/ff1_ble_device_connect.dart';
import 'package:app/app/providers/ff1_connect_session_provider.dart';
import 'package:app/app/providers/ff1_ensure_ready_provider.dart';
import 'package:app/app/providers/ff1_get_device_info_provider.dart';
import 'package:app/app/providers/ff1_providers.dart';
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
  FF1ConnectSession? _activeSession;

  @override
  Future<ConnectFF1State> build() async {
    return ConnectFF1Initial();
  }

  /// Connect to device via BLE
  ///
  /// Takes a [BluetoothDevice] and connects to it.
  /// Updates state to [ConnectFF1Connecting], then [ConnectFF1StillConnecting]
  /// after 15 seconds, and finally [ConnectFF1Connected] on success.
  /// Tracks terminal outcome in session.
  ///
  /// When [ff1DeviceInfo] is provided, skips get_info command and uses the
  /// supplied metadata (name, topic, internet status, branch, version).
  Future<void> connectBle(
    BluetoothDevice bluetoothDevice, {
    FF1DeviceInfo? ff1DeviceInfo,
  }) async {
    // Precondition: the BLE scan path requires device info to find the device
    // by name. Validate before starting a session so state = is unconditional
    // (no stale-emission concern exists yet).
    if (bluetoothDevice.remoteId.str.isEmpty && ff1DeviceInfo == null) {
      state = AsyncValue.data(
        ConnectFF1Error(exception: Exception('Device info is not provided')),
      );
      return;
    }

    final session = _startNewSession();

    final control = ref.read(ff1ControlProvider);
    var blDevice = bluetoothDevice;

    // For the deeplink flow (no device ID), we need to scan via BLE.
    // Check Bluetooth state BEFORE emitting any connecting state so the UI
    // never flashes "Connecting…" when BT is already off.
    // ff1DeviceInfo is guaranteed non-null here (precondition above).
    if (blDevice.remoteId.str.isEmpty) {
      if (control.currentAdapterState != BluetoothAdapterState.on) {
        _log.info('[ConnectFF1Notifier] BT adapter off, waiting for it');
        _setStateIfSessionActive(session, ConnectFF1BluetoothOff());
        try {
          await _waitForBtReady(control, session);
          _assertSessionActive(session);
        } on FF1ConnectionCancelledError catch (_) {
          _log.info('[ConnectFF1Notifier] Cancelled while waiting for BT');
          session.completeWithOutcome(FF1ConnectOutcome.cancelled);
          return;
        }
      }
    }

    // BT is ready (or not required for direct-device flow).
    // Now it is safe to show the connecting state and start the timer.
    _setStateIfSessionActive(
      session,
      ConnectFF1Connecting(blDevice: bluetoothDevice),
    );

    // Set up timer for "still connecting" state after 15 seconds
    session.scheduleTimer(
      const Duration(seconds: 15),
      () {
        if (!_isSessionActive(session)) {
          return;
        }

        if (state.value case ConnectFF1Connecting(:final blDevice)) {
          _setStateIfSessionActive(
            session,
            ConnectFF1StillConnecting(blDevice: blDevice),
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
        _assertSessionActive(session);
        if (foundDevice == null) {
          throw Exception(
            'FF1 device "${ff1DeviceInfo.name}" not found. '
            'Make sure it is powered on and nearby.',
          );
        }
        blDevice = foundDevice;
      }

      await control.connect(
        blDevice: blDevice,
        maxRetries: kFf1BleConnectMaxRetriesSessionDefault,
        shouldContinue: () => _isSessionActive(session),
      );
      _assertSessionActive(session);
      await _handlePostConnect(blDevice, ff1DeviceInfo, session: session);
      _log.info('[ConnectFF1Notifier] Successfully connected to device');
    } on FF1ConnectionCancelledError catch (_) {
      _log.info('[ConnectFF1Notifier] Connection cancelled by user');
      session.completeWithOutcome(FF1ConnectOutcome.cancelled);
    } on Exception catch (e) {
      _log.info('[ConnectFF1Notifier] Error connecting to device: $e');
      _setStateIfSessionActive(session, ConnectFF1Error(exception: e));
      session.completeWithOutcome(FF1ConnectOutcome.failed);
    } finally {
      _clearSession(session);
    }
  }

  Future<void> _handlePostConnect(
    BluetoothDevice blDevice,
    FF1DeviceInfo? initialFF1DeviceInfo, {
    required FF1ConnectSession session,
  }) async {
    _assertSessionActive(session);
    final deviceInfo = await ref.read(
      ff1GetDeviceInfoProvider(
        FF1GetDeviceInfoParams(
          blDevice: blDevice,
          deeplinkInfo: initialFF1DeviceInfo,
          shouldContinue: () => _isSessionActive(session),
        ),
      ).future,
    );
    _assertSessionActive(session);

    _log.info(
      '[ConnectFF1Page] Got device info: '
      'topicId=${deviceInfo.topicId}, '
      'internet=${deviceInfo.isConnectedToInternet}, '
      'branch=${deviceInfo.branchName}, '
      'version=${deviceInfo.version}',
    );

    final ensured = await ref.read(
      ff1EnsureReadyProvider(
        FF1EnsureReadyParams(
          blDevice: blDevice,
          deviceInfo: deviceInfo,
          shouldContinue: () => _isSessionActive(session),
        ),
      ).future,
    );
    _assertSessionActive(session);

    if (ensured == null) {
      // Legacy behavior: VersionService dialog shown; do not transition state.
      session.completeWithOutcome(FF1ConnectOutcome.failed);
      return;
    }

    _setStateIfSessionActive(
      session,
      ConnectFF1Connected(
        ff1device: ensured.ff1Device,
        portalIsSet: ensured.portalIsSet,
        isConnectedToInternet: ensured.isConnectedToInternet,
      ),
    );

    if (!ensured.isConnectedToInternet) {
      session.completeWithOutcome(FF1ConnectOutcome.needsWiFi);
      return;
    }
    if (ensured.portalIsSet) {
      session.completeWithOutcome(FF1ConnectOutcome.portalReady);
      return;
    }
    session.completeWithOutcome(FF1ConnectOutcome.wiFiReady);
  }

  /// Wait until Bluetooth adapter is [BluetoothAdapterState.on].
  ///
  /// Registers the completer on [session] so that [session.cancel()] —
  /// triggered by [cancelConnection] — unblocks this
  /// wait immediately via [FF1ConnectionCancelledError].
  Future<void> _waitForBtReady(
    FF1BleControl control,
    FF1ConnectSession session,
  ) async {
    final completer = Completer<void>();
    // Register the completer on the session so session.cancel() can
    // unblock this wait immediately.
    session.btReadyCompleter = completer;

    final sub = control.adapterStateStream.listen((s) {
      if (s == BluetoothAdapterState.on && !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await completer.future;
    } finally {
      unawaited(sub.cancel());
    }
  }

  /// Cancel the current connection attempt
  void cancelConnection() {
    final session = _activeSession;
    if (session == null) {
      return;
    }

    session.cancel();
    _activeSession = null;
  }

  /// Reset to initial state
  void reset() {
    cancelConnection();
    state = AsyncValue.data(ConnectFF1Initial());
  }

  bool _isSessionActive(FF1ConnectSession session) {
    return _activeSession?.id == session.id && !session.isCancelled;
  }

  void _assertSessionActive(FF1ConnectSession session) {
    if (!_isSessionActive(session)) {
      throw const FF1ConnectionCancelledError();
    }
  }

  void _setStateIfSessionActive(
    FF1ConnectSession session,
    ConnectFF1State value,
  ) {
    if (_isSessionActive(session)) {
      state = AsyncValue.data(value);
    }
  }

  void _clearSession(FF1ConnectSession session) {
    session.cancel();
    if (_activeSession?.id == session.id) {
      _activeSession = null;
    }
  }

  FF1ConnectSession _startNewSession() {
    final previous = _activeSession;
    if (previous != null) {
      // A new attempt supersedes any in-flight attempt. Cancel immediately so
      // waits such as BT-ready are unblocked instead of hanging until a later
      // active-session assertion point.
      if (!previous.isTerminal) {
        previous.completeWithOutcome(FF1ConnectOutcome.cancelled);
      }
      previous.cancel();
    }

    final factory = ref.read(ff1ConnectSessionFactoryProvider);
    final session = factory.createSession();
    _activeSession = session;
    return session;
  }
}

/// Provider for connect FF1 flow
final connectFF1Provider =
    AsyncNotifierProvider<ConnectFF1Notifier, ConnectFF1State>(
      ConnectFF1Notifier.new,
    );
