import 'package:app/app/providers/search_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('searchQueryProvider updates and clears query', () {
    // Unit test: verifies search query notifier supports set and clear operations.
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final notifier = container.read(searchQueryProvider.notifier);
    notifier.setQuery('feral');
    expect(container.read(searchQueryProvider), 'feral');

    notifier.clear();
    expect(container.read(searchQueryProvider), '');
  });

  test('searchResultsProvider returns empty results for empty query', () async {
    // Unit test: verifies search results short-circuit to empty payload when query is blank.
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final results = await container.read(searchResultsProvider.future);
    expect(results.isEmpty, isTrue);
    expect(results.totalCount, 0);
  });

  test(
    'searchSuggestionsProvider returns no suggestions for short query',
    () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      container.read(searchInputQueryProvider.notifier).setQuery('a');
      final suggestions = await container.read(
        searchSuggestionsProvider.future,
      );
      expect(suggestions, isEmpty);
    },
  );

  test('searchInputQueryProvider tracks typing state', () {
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final notifier = container.read(searchInputQueryProvider.notifier);
    notifier.setQuery('dmi');
    expect(container.read(searchInputQueryProvider), 'dmi');

    notifier.clear();
    expect(container.read(searchInputQueryProvider), '');
  });
}
