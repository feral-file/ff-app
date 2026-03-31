import 'dart:async';

import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pollWithRecovery', () {
    test(
      'recovers after a transient exception and yields the next success',
      () async {
        var attempts = 0;

        final value = await pollWithRecovery<int>(
          load: () async {
            attempts += 1;
            if (attempts == 1) {
              throw Exception('temporary relayer failure');
            }
            return 42;
          },
          interval: const Duration(milliseconds: 1),
        ).first;

        expect(value, 42);
        expect(attempts, 2);
      },
    );

    test('stops polling after the subscription is cancelled', () async {
      var attempts = 0;
      final firstValue = Completer<void>();

      final subscription =
          pollWithRecovery<int>(
            load: () async {
              attempts += 1;
              return attempts;
            },
            interval: const Duration(milliseconds: 5),
          ).listen((_) {
            firstValue.complete();
          });

      await firstValue.future;
      await subscription.cancel();

      final attemptsAtCancel = attempts;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(attempts, attemptsAtCancel);
    });
  });
}
