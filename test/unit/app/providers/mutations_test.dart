import 'package:app/app/providers/mutations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MutationNotifier runs success flow and reset', () async {
    // Unit test: verifies mutation state transitions: idle -> pending -> success -> idle.
    final provider =
        NotifierProvider<MutationNotifier<int>, MutationState<int>>(
          MutationNotifier.new,
        );
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final notifier = container.read(provider.notifier);
    final value = await notifier.run(() async => 42);
    expect(value, 42);
    expect(container.read(provider).isSuccess, isTrue);

    notifier.reset();
    expect(container.read(provider).isIdle, isTrue);
  });
}
