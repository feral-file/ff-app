import 'package:app/app/providers/search_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/ui/screens/tabs/search_tab_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SearchTabPage matches old SearchPage states and type switch', (
    tester,
  ) async {
    final fakeResults = SearchResults(
      channels: const [
        Channel(id: 'ch_1', name: 'Channel A', type: ChannelType.dp1),
      ],
      playlists: const [
        Playlist(id: 'pl_1', name: 'Playlist A', type: PlaylistType.dp1),
      ],
      works: [
        PlaylistItem(
          id: 'wk_1',
          kind: PlaylistItemKind.dp1Item,
          title: 'Work A',
        ),
      ],
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
      find.text('Search for channels, playlists, or works'),
      findsOneWidget,
    );

    // Submit a query via keyboard action
    await tester.enterText(find.byType(TextField), 'feral');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

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

    // Switch filter type to Playlists via the type menu
    await tester.tap(find.text('Channels').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Playlists').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Playlist A'), findsOneWidget);
  });
}
