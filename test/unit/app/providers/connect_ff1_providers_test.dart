import 'package:app/app/providers/connect_ff1_providers.dart';
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
}
