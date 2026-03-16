import 'dart:async';

import 'package:app/infra/database/async_once.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('run returns the same in-flight future result for concurrent calls', () async {
    final once = AsyncOnce<int>();
    final completer = Completer<int>();
    var callCount = 0;

    Future<int> task() {
      callCount += 1;
      return completer.future;
    }

    final first = once.run(task);
    final second = once.run(task);

    expect(callCount, 1);

    completer.complete(42);

    expect(await first, 42);
    expect(await second, 42);
  });

  test('run caches value after completion and does not rerun task', () async {
    final once = AsyncOnce<int>();
    var callCount = 0;

    Future<int> task() async {
      callCount += 1;
      return 7;
    }

    expect(await once.run(task), 7);
    expect(await once.run(task), 7);
    expect(callCount, 1);
  });

  test('run clears in-flight state when task fails and allows retry', () async {
    final once = AsyncOnce<int>();
    var callCount = 0;

    Future<int> task() async {
      callCount += 1;
      if (callCount == 1) {
        throw StateError('boom');
      }
      return 9;
    }

    await expectLater(once.run(task), throwsA(isA<StateError>()));
    expect(await once.run(task), 9);
    expect(callCount, 2);
  });
}
