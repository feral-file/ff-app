import 'package:app/app/providers/channel_detail_provider.dart';
import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/me_section_playlists_provider.dart';
import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/providers/publisher_section_providers.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/app/providers/works_provider.dart';
import 'package:app/app/routing/all_playlists_route.dart';
import 'package:app/app/routing/previous_page_title_extra.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/ui/screens/all_playlists_screen.dart';
import 'package:app/ui/screens/channel_detail_screen.dart';
import 'package:app/ui/screens/tabs/playlists_tab_page.dart';
import 'package:app/ui/screens/tabs/works_tab_page.dart';
import 'package:app/widgets/work_grid_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _SeedDoneNotifier extends SeedDownloadNotifier {
  @override
  SeedDownloadState build() {
    return const SeedDownloadState(status: SeedDownloadStatus.done);
  }
}

class _SeedNotReadyNotifier extends SeedDatabaseReadyNotifier {
  @override
  bool build() => false;
}

class _StubPlaylistsNotifier extends PlaylistsNotifier {
  _StubPlaylistsNotifier(super.type, this._state);

  final PlaylistsState _state;

  @override
  PlaylistsState build() => _state;

  @override
  Future<void> loadPlaylists({int? size}) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}
}

class _StubWorksNotifier extends WorksNotifier {
  _StubWorksNotifier(this._state);

  final WorksState _state;

  @override
  WorksState build() => _state;

  @override
  void setActive(bool active) {}

  @override
  Future<void> loadWorks() async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}

  @override
  void updateVisibleRange({
    required int startIndex,
    required int endIndex,
  }) {}
}

void main() {
  group('back title navigation', () {
    testWidgets('home playlists view-all shows Playlists as back title', (
      tester,
    ) async {
      final curatedPlaylists = List<Playlist>.generate(
        6,
        (index) => Playlist(
          id: 'playlist_$index',
          name: 'Playlist $index',
          type: PlaylistType.dp1,
          channelId: 'channel_$index',
          itemCount: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seedDownloadProvider.overrideWith(_SeedDoneNotifier.new),
            isSeedDatabaseReadyProvider.overrideWith(_SeedNotReadyNotifier.new),
            playlistsProvider(PlaylistType.dp1).overrideWith(
              () => _StubPlaylistsNotifier(
                PlaylistType.dp1,
                PlaylistsState.loaded(
                  playlists: curatedPlaylists,
                  hasMore: false,
                  cursor: null,
                ),
              ),
            ),
            meSectionPlaylistsProvider.overrideWith(
              (ref) => Stream.value(
                const MeSectionPlaylistsState(
                  playlists: <Playlist>[],
                  isLoading: false,
                ),
              ),
            ),
            publisherTitlesMapProvider.overrideWith((ref) => Stream.value({})),
            allChannelsByIdMapProvider.overrideWith((ref) => Stream.value({})),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) =>
                      const Scaffold(body: PlaylistsTabPage(isActive: true)),
                ),
                GoRoute(
                  path: '/playlists/all',
                  builder: (context, state) {
                    final params = parseAllPlaylistsQuery(
                      state.uri.queryParameters,
                    );
                    final metadata = deriveAllPlaylistsMetadata(params);
                    return AllPlaylistsScreen(
                      channelTypes: params.channelTypes,
                      channelIds: params.channelIds,
                      playlistTypes: params.playlistTypes,
                      title: metadata.title,
                      description: metadata.description,
                      iconAsset: metadata.iconAsset,
                      backTitle: previousPageTitleFromExtra(state.extra),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Index'), findsNothing);
      expect(find.text('Playlists'), findsWidgets);
      expect(find.text('Curated'), findsWidgets);
    });

    testWidgets('channel detail view-all shows channel name as back title', (
      tester,
    ) async {
      const channelId = 'ch_1';
      const channelName = 'My Channel';
      final channelPlaylists = List<Playlist>.generate(
        6,
        (index) => Playlist(
          id: 'channel_playlist_$index',
          name: 'Channel Playlist $index',
          type: PlaylistType.dp1,
          channelId: channelId,
          itemCount: 1,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            channelDetailsProvider(channelId).overrideWith(
              (ref) => Stream.value(
                ChannelDetails(
                  channel: const Channel(
                    id: channelId,
                    name: channelName,
                    type: ChannelType.localVirtual,
                  ),
                  playlists: channelPlaylists,
                ),
              ),
            ),
            channelPlaylistsFromIdsProvider(channelId).overrideWith(
              (ref) => Stream.value(channelPlaylists),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/channels/$channelId',
              routes: [
                GoRoute(
                  path: '/channels/:channelId',
                  builder: (context, state) =>
                      ChannelDetailScreen(channelId: channelId),
                ),
                GoRoute(
                  path: '/playlists/all',
                  builder: (context, state) {
                    final params = parseAllPlaylistsQuery(
                      state.uri.queryParameters,
                    );
                    final metadata = deriveAllPlaylistsMetadata(params);
                    return AllPlaylistsScreen(
                      channelTypes: params.channelTypes,
                      channelIds: params.channelIds,
                      playlistTypes: params.playlistTypes,
                      title: metadata.title,
                      description: metadata.description,
                      iconAsset: metadata.iconAsset,
                      backTitle: previousPageTitleFromExtra(state.extra),
                    );
                  },
                ),
                GoRoute(
                  path: '/works/:workId',
                  builder: (context, state) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Index'), findsNothing);
      expect(find.text(channelName), findsWidgets);
      expect(find.text('Playlists'), findsWidgets);
    });

    testWidgets('works tab pushes work detail with Works back title', (
      tester,
    ) async {
      Object? pushedExtra;
      final works = [
        const PlaylistItem(
          id: 'work_1',
          kind: PlaylistItemKind.dp1Item,
          title: 'Work 1',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            seedDownloadProvider.overrideWith(_SeedDoneNotifier.new),
            worksProvider.overrideWith(
              () => _StubWorksNotifier(
                WorksState.loaded(works: works, hasMore: false),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) =>
                      const Scaffold(body: WorksTabPage(isActive: true)),
                ),
                GoRoute(
                  path: '/works/:workId',
                  name: RouteNames.workDetail,
                  builder: (context, state) {
                    pushedExtra = state.extra;
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.ensureVisible(find.byType(WorkGridCard).first);
      await tester.tap(find.byType(WorkGridCard).first);
      await tester.pumpAndSettle();

      expect(previousPageTitleFromExtra(pushedExtra), 'Works');
    });
  });
}
