import 'package:app/app/providers/app_lifecycle_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('appLifecycleProvider builds with a lifecycle state', () {
    // Unit test: verifies lifecycle notifier exposes current lifecycle value.
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final state = container.read(appLifecycleProvider);
    expect(state, isA<AppLifecycleState>());
  });
}
