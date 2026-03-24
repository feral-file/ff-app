import 'dart:async';

import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/domain/models/ff1_connect_session.dart';
import 'package:app/domain/models/ff1_error.dart';
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
}
