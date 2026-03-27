import 'package:app/app/providers/app_provider_observer.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:riverpod/misc.dart' show ProviderException;

import 'provider_test_helpers.dart';

void main() {
  test('FF1ConnectionCancelledError does not emit provider_failed log', () {
    final records = <LogRecord>[];
    final logger = Logger('ObserverTest')..onRecord.listen(records.add);
    final observer = AppProviderObserver(logger: logger);
    // Sync failure: same [providerDidFail] path as async ensure-ready cancellation.
    final cancelProvider = Provider<void>(
      (ref) => throw const FF1ConnectionCancelledError(),
    );
    final container = ProviderContainer.test(
      observers: [observer],
    );
    addTearDown(container.dispose);

    try {
      container.read(cancelProvider);
      fail('expected read to throw');
    } on Object catch (e) {
      // Sync Provider wraps the root cause in [ProviderException] for readers;
      // [providerDidFail] still receives [FF1ConnectionCancelledError].
      final root = e is ProviderException ? e.exception : e;
      expect(root, isA<FF1ConnectionCancelledError>());
    }

    final providerFailed = records.where(
      (r) => r.message.contains('provider_failed'),
    );
    expect(providerFailed, isEmpty);
  });

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
