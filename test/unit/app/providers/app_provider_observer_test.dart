import 'package:app/app/providers/app_provider_observer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'provider_test_helpers.dart';

void main() {
  test('AppProviderObserver handles add/update/fail events', () {
    // Unit test: verifies provider observer receives lifecycle/failure events safely.
    final records = <LogRecord>[];
    final logger = Logger('ObserverTest')..onRecord.listen(records.add);
    final observer = AppProviderObserver(logger: logger);
    final counter = NotifierProvider<CounterNotifier, int>(CounterNotifier.new);
    final broken = Provider<int>((ref) => throw StateError('boom'));
    final container = ProviderContainer.test(observers: [observer]);
    addTearDown(container.dispose);

    expect(container.read(counter), 0);
    container.read(counter.notifier).increment();
    expect(() => container.read(broken), throwsA(anything));
    expect(records, isNotEmpty);
  });
}
