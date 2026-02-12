import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_test_helpers.dart';

void main() {
  test('TokensSyncState copyWith updates fields', () {
    // Unit test: verifies data-state copy semantics for token sync coordinator state.
    const initial = TokensSyncState();
    final next = initial.copyWith(
      syncingAddresses: {'0xabc'},
      errorMessage: 'failed',
    );
    expect(next.syncingAddresses, {'0xabc'});
    expect(next.errorMessage, 'failed');
  });

  test('tokensSyncCoordinatorProvider builds with fake worker/app state', () {
    // Unit test: verifies coordinator notifier can initialize with mocked dependencies.
    final container = ProviderContainer.test(
      overrides: [
        appStateServiceProvider.overrideWithValue(MockAppStateService()),
        indexerTokensWorkerProvider.overrideWithValue(
          FakeIndexerTokensWorker(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(tokensSyncCoordinatorProvider);
    expect(state.syncingAddresses, isEmpty);
    expect(state.errorMessage, isNull);
  });
}
