import 'package:app/app/utils/await_parallel_futures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completes when one future throws', () async {
    var ranThird = false;
    await awaitParallelFuturesIgnoringErrors([
      Future<void>.value(),
      Future<void>.error(Exception('fail'), StackTrace.current),
      Future<void>(() async {
        ranThird = true;
      }),
    ]);
    expect(ranThird, isTrue);
  });

  test('completes when all succeed', () async {
    var n = 0;
    await awaitParallelFuturesIgnoringErrors([
      Future<void>(() async {
        n++;
      }),
      Future<void>(() async {
        n++;
      }),
    ]);
    expect(n, 2);
  });
}
