import 'dart:async';

import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/ff1_connect_session_provider.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/domain/models/ff1_connect_session.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_commands.dart';
import 'package:app/infra/ff1/ble_protocol/ff1_ble_protocol.dart';
import 'package:app/infra/ff1/ble_transport/ff1_ble_transport.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connectFF1Provider builds and resets to initial state', () async {
    // Unit test: verifies connect-FF1 notifier initial and reset state transitions.
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    await container.read(connectFF1Provider.future);
    expect(container.read(connectFF1Provider).value, isA<ConnectFF1Initial>());

    container.read(connectFF1Provider.notifier).reset();
    expect(container.read(connectFF1Provider).value, isA<ConnectFF1Initial>());
  });

  test('session cancel() throws FF1ConnectionCancelledError', () async {
    // Test: verifies that FF1ConnectSession.cancel() completes the BT wait
    // completer with FF1ConnectionCancelledError (not _FF1SessionCancelledError).
    final session = FF1ConnectSession(1);
    final completer = Completer<void>();
    session.btReadyCompleter = completer;

    // Cancel session
    session.cancel();

    // Should throw FF1ConnectionCancelledError
    expect(
      () => completer.future,
      throwsA(isA<FF1ConnectionCancelledError>()),
    );
  });

  test(
    'starting a new connect attempt cancels previous active session immediately',
    () async {
      final factory = _RecordingSessionFactory();
      final container = ProviderContainer.test(
        overrides: [
          ff1ConnectSessionFactoryProvider.overrideWithValue(factory),
          ff1ControlProvider.overrideWithValue(_BluetoothOffControl()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(connectFF1Provider.notifier);
      const info = FF1DeviceInfo(
        deviceId: 'FF1-TEST',
        topicId: '',
        isConnectedToInternet: false,
        branchName: 'release',
        version: '1.0.0',
      );
      final emptyDevice = BluetoothDevice.fromId('');

      final firstAttempt = notifier.connectBle(
        emptyDevice,
        ff1DeviceInfo: info,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(factory.sessions, hasLength(1));
      expect(factory.sessions.first.isCancelled, isFalse);

      final secondAttempt = notifier.connectBle(
        emptyDevice,
        ff1DeviceInfo: info,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(factory.sessions, hasLength(2));
      expect(factory.sessions.first.isCancelled, isTrue);
      expect(factory.sessions.first.outcome, FF1ConnectOutcome.cancelled);

      notifier.cancelConnection();
      await Future.wait<void>([firstAttempt, secondAttempt]);
    },
  );
}

class _RecordingSessionFactory extends FF1ConnectSessionFactory {
  final List<FF1ConnectSession> sessions = <FF1ConnectSession>[];

  @override
  FF1ConnectSession createSession() {
    final session = super.createSession();
    sessions.add(session);
    return session;
  }
}

class _BluetoothOffControl extends FF1BleControl {
  _BluetoothOffControl() : super(transport: _NoopBleTransport());

  @override
  BluetoothAdapterState get currentAdapterState => BluetoothAdapterState.off;

  @override
  Stream<BluetoothAdapterState> get adapterStateStream =>
      const Stream<BluetoothAdapterState>.empty();
}

class _NoopBleTransport implements FF1BleTransport {
  @override
  BluetoothAdapterState get adapterState => BluetoothAdapterState.off;

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
