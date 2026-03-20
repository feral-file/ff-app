import 'package:app/app/providers/search_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/ui/screens/tabs/search_tab_page.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late bool? previousDatabaseWarningSetting;

  setUpAll(() {
    previousDatabaseWarningSetting =
        driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  tearDownAll(() {
    if (previousDatabaseWarningSetting != null) {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases =
          previousDatabaseWarningSetting!;
    }
  });

  Future<void> openFilterAndSelect(
    WidgetTester tester, {
    required String menuLabel,
    required String optionLabel,
  }) async {
    await tester.tap(find.widgetWithText(TextButton, menuLabel).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    var optionFinder = find.text(optionLabel);
    final optionCount = optionFinder.evaluate().length;

    if (optionCount > 1) {
      optionFinder = optionFinder.last;
    }

    expect(
      optionFinder,
      findsOneWidget,
      reason:
          'Expected filter option "$optionLabel" to be visible in popup menu',
    );

    await tester.tap(optionFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> selectTypeFilter(WidgetTester tester, String typeLabel) async {
    await tester.tap(find.widgetWithText(TextButton, typeLabel).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('SearchTabPage matches old SearchPage states and type switch', (
    tester,
  ) async {
    const fakeResults = SearchResults(
      channels: [
        Channel(id: 'ch_1', name: 'Channel A', type: ChannelType.dp1),
      ],
      playlists: [
        Playlist(id: 'pl_1', name: 'Playlist A', type: PlaylistType.dp1),
      ],
      works: [
        PlaylistItem(
          id: 'wk_1',
          kind: PlaylistItemKind.dp1Item,
          title: 'Work A',
        ),
      ],
      artistMatchedWorkIds: {'wk_1'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchResultsProvider.overrideWith((ref) async {
            final query = ref.watch(searchQueryProvider);
            if (query.isEmpty) {
              return const SearchResults(
                channels: [],
                playlists: [],
                works: [],
                artistMatchedWorkIds: <String>{},
              );
            }
            return fakeResults;
          }),
        ],
        child: const MaterialApp(
          home: SearchTabPage(),
        ),
      ),
    );

    // Initial view (query empty)
    expect(
      find.text('Search for channels, playlists, works, or artists'),
      findsOneWidget,
    );

    // Submit a query via keyboard action
    await tester.enterText(find.byType(TextField), 'feral');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Default filter type matches old (channels)
    expect(find.text('Channels'), findsWidgets);
    expect(find.text('Channel A'), findsOneWidget);

    // Clearing the input text must not clear the results view
    // (because results are driven by submitted query, not transient input).
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);
    expect(find.text('Channel A'), findsOneWidget);

    // Switch filter type to Playlists via horizontal type tabs.
    await selectTypeFilter(tester, 'Playlists');

    expect(find.text('Playlist A'), findsOneWidget);
  });

  testWidgets('SearchTabPage shows live suggestions while typing', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchResultsProvider.overrideWith((ref) async {
            return const SearchResults(
              channels: [],
              playlists: [],
              works: [],
              artistMatchedWorkIds: <String>{},
            );
          }),
          searchSuggestionsProvider.overrideWith((ref) async {
            return const [
              SearchSuggestion(
                id: 'ch_live',
                title: 'Live Channel',
                subtitle: 'Channel',
                kind: SearchResultKind.channel,
              ),
              SearchSuggestion(
                id: 'wk_live',
                title: 'Live Work',
                subtitle: 'Work',
                kind: SearchResultKind.work,
              ),
            ];
          }),
        ],
        child: const MaterialApp(
          home: SearchTabPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'di');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Suggestions'), findsOneWidget);
    expect(find.text('Live Channel'), findsOneWidget);
    expect(find.text('Live Work'), findsOneWidget);
  });

  testWidgets('SearchTabPage applies source filter menu selections', (
    tester,
  ) async {
    const fakeResults = SearchResults(
      playlists: [
        Playlist(
          id: 'pl_dp1',
          name: 'DP1 Playlist',
          type: PlaylistType.dp1,
        ),
        Playlist(
          id: 'pl_local',
          name: 'Personal Playlist',
          type: PlaylistType.addressBased,
        ),
      ],
      channels: [],
      works: [
        PlaylistItem(
          id: 'wk_dp1',
          kind: PlaylistItemKind.dp1Item,
          title: 'DP1 Work',
        ),
      ],
      artistMatchedWorkIds: {'wk_dp1'},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchResultsProvider.overrideWith((ref) async {
            final query = ref.watch(searchQueryProvider);
            if (query.isEmpty) {
              return const SearchResults(
                channels: [],
                playlists: [],
                works: [],
                artistMatchedWorkIds: <String>{},
              );
            }
            return fakeResults;
          }),
          searchSuggestionsProvider.overrideWith((_) async => const []),
        ],
        child: const MaterialApp(
          home: SearchTabPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'feral');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('DP1 Playlist'), findsOneWidget);
    expect(find.text('Personal Playlist'), findsOneWidget);

    await openFilterAndSelect(
      tester,
      menuLabel: 'All Sources',
      optionLabel: 'DP-1',
    );

    expect(find.text('DP1 Playlist'), findsOneWidget);
    expect(find.text('Personal Playlist'), findsNothing);

    await openFilterAndSelect(
      tester,
      menuLabel: 'DP-1',
      optionLabel: 'Personal',
    );

    expect(find.text('DP1 Playlist'), findsNothing);
    expect(find.text('Personal Playlist'), findsOneWidget);
  });

  testWidgets('SearchTabPage applies date filter menu selections', (
    tester,
  ) async {
    final now = DateTime.now();

    const baseResults = SearchResults(
      playlists: [],
      works: [],
      channels: [],
      artistMatchedWorkIds: <String>{},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchResultsProvider.overrideWith((ref) async {
            final query = ref.watch(searchQueryProvider);
            if (query.isEmpty) {
              return const SearchResults(
                channels: [],
                playlists: [],
                works: [],
                artistMatchedWorkIds: <String>{},
              );
            }
            return SearchResults(
              channels: baseResults.channels,
              playlists: [
                Playlist(
                  id: 'pl_recent',
                  name: 'Recent Playlist',
                  type: PlaylistType.dp1,
                  updatedAt: now.subtract(const Duration(days: 1)),
                ),
                Playlist(
                  id: 'pl_older',
                  name: 'Older Playlist',
                  type: PlaylistType.dp1,
                  updatedAt: DateTime(2020),
                ),
              ],
              artistMatchedWorkIds: baseResults.artistMatchedWorkIds,
              works: baseResults.works,
            );
          }),
          searchSuggestionsProvider.overrideWith((_) async => const []),
        ],
        child: const MaterialApp(
          home: SearchTabPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'feral');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Recent Playlist'), findsOneWidget);
    expect(find.text('Older Playlist'), findsOneWidget);

    await openFilterAndSelect(
      tester,
      menuLabel: 'All Time',
      optionLabel: 'Last Week',
    );

    expect(find.text('Recent Playlist'), findsOneWidget);
    expect(find.text('Older Playlist'), findsNothing);

    await openFilterAndSelect(
      tester,
      menuLabel: 'Last Week',
      optionLabel: 'Older',
    );

    expect(find.text('Recent Playlist'), findsNothing);
    expect(find.text('Older Playlist'), findsOneWidget);
  });

  testWidgets('SearchTabPage applies source and date filters together', (
    tester,
  ) async {
    final now = DateTime.now();
    final recentDate = now.subtract(const Duration(days: 1));
    final oldDate = now.subtract(const Duration(days: 400));

    const baseResults = SearchResults(
      channels: [],
      works: [],
      playlists: [],
      artistMatchedWorkIds: <String>{},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchResultsProvider.overrideWith((ref) async {
            final query = ref.watch(searchQueryProvider);
            if (query.isEmpty) {
              return const SearchResults(
                channels: [],
                playlists: [],
                works: [],
                artistMatchedWorkIds: <String>{},
              );
            }
            return SearchResults(
              channels: baseResults.channels,
              works: baseResults.works,
              artistMatchedWorkIds: baseResults.artistMatchedWorkIds,
              playlists: [
                Playlist(
                  id: 'pl_dp1_recent',
                  name: 'DP1 Recent',
                  type: PlaylistType.dp1,
                  updatedAt: recentDate,
                ),
                Playlist(
                  id: 'pl_dp1_older',
                  name: 'DP1 Older',
                  type: PlaylistType.dp1,
                  updatedAt: oldDate,
                ),
              ],
            );
          }),
          searchSuggestionsProvider.overrideWith((_) async => const []),
        ],
        child: const MaterialApp(
          home: SearchTabPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'feral');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('DP1 Recent'), findsOneWidget);
    expect(find.text('DP1 Older'), findsOneWidget);

    await openFilterAndSelect(
      tester,
      menuLabel: 'All Sources',
      optionLabel: 'DP-1',
    );

    expect(find.text('DP1 Recent'), findsOneWidget);
    expect(find.text('DP1 Older'), findsOneWidget);

    await openFilterAndSelect(
      tester,
      menuLabel: 'All Time',
      optionLabel: 'Last Week',
    );

    expect(find.text('DP1 Recent'), findsOneWidget);
    expect(find.text('DP1 Older'), findsNothing);

    await openFilterAndSelect(
      tester,
      menuLabel: 'Last Week',
      optionLabel: 'All Time',
    );

    expect(find.text('DP1 Recent'), findsOneWidget);
    expect(find.text('DP1 Older'), findsOneWidget);

    await openFilterAndSelect(
      tester,
      menuLabel: 'DP-1',
      optionLabel: 'All Sources',
    );

    expect(find.text('DP1 Recent'), findsOneWidget);
    expect(find.text('DP1 Older'), findsOneWidget);
  });
}
