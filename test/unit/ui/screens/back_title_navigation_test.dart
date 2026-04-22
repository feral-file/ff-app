import 'package:app/app/providers/channel_detail_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/me_section_playlists_provider.dart';
import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/app/providers/playlist_details_provider.dart';
import 'package:app/app/providers/playlists_provider.dart';
import 'package:app/app/providers/publisher_section_providers.dart';
import 'package:app/app/providers/seed_database_provider.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/app/providers/works_provider.dart';
import 'package:app/app/routing/all_playlists_route.dart';
import 'package:app/app/routing/previous_page_title_extra.dart';
import 'package:app/app/routing/previous_page_title_scope.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/ui/screens/all_playlists_screen.dart';
import 'package:app/ui/screens/channel_detail_screen.dart';
import 'package:app/ui/screens/playlist_detail_screen.dart';
import 'package:app/ui/screens/tabs/playlists_tab_page.dart';
import 'package:app/ui/screens/tabs/works_tab_page.dart';
import 'package:app/ui/screens/work_detail_screen.dart';
import 'package:app/widgets/now_displaying_bar/now_displaying_bar.dart';
import 'package:app/widgets/work_grid_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/provider_test_helpers.dart';

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
  // PlaylistsNotifier stores this positional argument in a private `_type`
  // field, so the test double cannot match the superclass parameter name.
  // ignore: matching_super_parameters
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

class _StaticPlaylistDetailsNotifier extends PlaylistDetailsNotifier {
  // PlaylistDetailsNotifier stores this family argument in a private
  // `_playlistId` field, so the test double cannot match the parameter name.
  // ignore: matching_super_parameters
  _StaticPlaylistDetailsNotifier(super.playlistId, this._state);

  final AsyncValue<PlaylistDetailsState> _state;

  @override
  AsyncValue<PlaylistDetailsState> build() => _state;
}

class _StaticWorkDetailNotifier extends WorkDetailNotifier {
  // WorkDetailNotifier stores this family argument in a private `_itemId`
  // field, so the test double cannot match the parameter name.
  // ignore: matching_super_parameters
  _StaticWorkDetailNotifier(super.itemId, this._state);

  final AsyncValue<WorkDetailData?> _state;

  @override
  AsyncValue<WorkDetailData?> build() => _state;
}

class _StaticNowDisplayingNotifier extends NowDisplayingNotifier {
  _StaticNowDisplayingNotifier(this._state);

  final NowDisplayingStatus _state;

  @override
  NowDisplayingStatus build() => _state;
}

class _StaticNowDisplayingVisibilityNotifier
    extends NowDisplayingVisibilityNotifier {
  _StaticNowDisplayingVisibilityNotifier(this._state);

  final NowDisplayingVisibilityState _state;

  @override
  NowDisplayingVisibilityState build() => _state;
}

class _ScopedTitlePage extends StatelessWidget {
  const _ScopedTitlePage({
    required this.title,
    this.child = const SizedBox.shrink(),
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PreviousPageTitleScope(
      title: title,
      child: Scaffold(body: child),
    );
  }
}

class _MutableScopedTitlePage extends StatefulWidget {
  const _MutableScopedTitlePage({
    required this.initialTitle,
    required this.updatedTitle,
  });

  final String initialTitle;
  final String updatedTitle;

  @override
  State<_MutableScopedTitlePage> createState() =>
      _MutableScopedTitlePageState();
}

class _MutableScopedTitlePageState extends State<_MutableScopedTitlePage> {
  late String _title = widget.initialTitle;

  @override
  Widget build(BuildContext context) {
    return PreviousPageTitleScope(
      title: _title,
      child: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _title = widget.updatedTitle;
              });
            },
            child: const Text('Update title'),
          ),
        ),
      ),
    );
  }
}

Widget _appWithNowDisplayingOverlay({
  required GoRouter router,
}) {
  return MaterialApp.router(
    routerConfig: router,
    builder: (context, child) => Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => Stack(
            children: [
              child ?? const SizedBox.shrink(),
              NowDisplayingBarOverlay(router: router),
            ],
          ),
        ),
      ],
    ),
  );
}

const _visibleNowDisplayingState = NowDisplayingVisibilityState(
  shouldShowNowDisplaying: true,
  nowDisplayingVisibility: true,
  bottomSheetVisibility: false,
  keyboardVisibility: false,
  hasFF1: true,
  workDetailPanelExpanded: false,
);

const _testDevice = FF1Device(
  name: 'Living Room FF1',
  remoteId: 'remote-1',
  deviceId: 'device-1',
  topicId: 'topic-1',
);

NowDisplayingSuccess _nowDisplayingSuccess({
  required String workId,
  required String title,
}) {
  return NowDisplayingSuccess(
    DP1NowDisplayingObject(
      connectedDevice: _testDevice,
      index: 0,
      items: [
        PlaylistItem(
          id: workId,
          kind: PlaylistItemKind.dp1Item,
          title: title,
        ),
      ],
      isSleeping: false,
    ),
  );
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
            allChannelsByIdMapProvider.overrideWithValue(
              const <String, Channel>{},
            ),
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
                      const ChannelDetailScreen(channelId: channelId),
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

    testWidgets(
      'direct all playlists entry does not invent a channel back title',
      (tester) async {
        const channelId = 'ch_1';
        const channelName = 'Deep Link Channel';

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              channelPlaylistsFromIdsProvider(channelId).overrideWith(
                (ref) => Stream.value(const <Playlist>[]),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: '/playlists/all?channelIds=$channelId',
                routes: [
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

        await tester.pumpAndSettle();

        expect(find.text(channelName), findsNothing);
        expect(find.text('Back'), findsNothing);
        expect(find.bySemanticsLabel('Back Button'), findsOneWidget);
      },
    );

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

    testWidgets(
      'now displaying bar uses the latest page title after switching pages',
      (tester) async {
        Object? pushedExtra;
        late GoRouter router;

        router = GoRouter(
          initialLocation: '/playlists',
          routes: [
            GoRoute(
              path: '/playlists',
              builder: (context, state) => _ScopedTitlePage(
                title: 'Playlists',
                child: Center(
                  child: ElevatedButton(
                    onPressed: () => context.go('/channels'),
                    child: const Text('Go to channels'),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/channels',
              builder: (context, state) =>
                  const _ScopedTitlePage(title: 'Channels'),
            ),
            GoRoute(
              path: '/works/:workId',
              builder: (context, state) {
                pushedExtra = state.extra;
                return const SizedBox.shrink();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nowDisplayingProvider.overrideWith(
                () => _StaticNowDisplayingNotifier(
                  _nowDisplayingSuccess(
                    workId: 'work_2',
                    title: 'Overlay Work 2',
                  ),
                ),
              ),
              nowDisplayingVisibilityProvider.overrideWith(
                () => _StaticNowDisplayingVisibilityNotifier(
                  _visibleNowDisplayingState,
                ),
              ),
              ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
              ff1SupportsShuffleProvider.overrideWithValue(false),
              ff1SupportsLoopProvider.overrideWithValue(false),
            ],
            child: _appWithNowDisplayingOverlay(router: router),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Go to channels'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Overlay Work 2'));
        await tester.pumpAndSettle();

        expect(previousPageTitleFromExtra(pushedExtra), 'Channels');
      },
    );

    testWidgets(
      'now displaying bar reads the latest mirrored title on the same route',
      (tester) async {
        Object? pushedExtra;
        late GoRouter router;

        router = GoRouter(
          initialLocation: '/playlists',
          routes: [
            GoRoute(
              path: '/playlists',
              builder: (context, state) => const _MutableScopedTitlePage(
                initialTitle: 'Playlists',
                updatedTitle: 'Loaded Playlists',
              ),
            ),
            GoRoute(
              path: '/works/:workId',
              builder: (context, state) {
                pushedExtra = state.extra;
                return const SizedBox.shrink();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nowDisplayingProvider.overrideWith(
                () => _StaticNowDisplayingNotifier(
                  _nowDisplayingSuccess(
                    workId: 'work_2',
                    title: 'Overlay Work 2',
                  ),
                ),
              ),
              nowDisplayingVisibilityProvider.overrideWith(
                () => _StaticNowDisplayingVisibilityNotifier(
                  _visibleNowDisplayingState,
                ),
              ),
              ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
              ff1SupportsShuffleProvider.overrideWithValue(false),
              ff1SupportsLoopProvider.overrideWithValue(false),
            ],
            child: _appWithNowDisplayingOverlay(router: router),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Update title'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Overlay Work 2'));
        await tester.pumpAndSettle();

        expect(previousPageTitleFromExtra(pushedExtra), 'Loaded Playlists');
      },
    );

    testWidgets(
      'channel detail loading state publishes a fallback overlay title',
      (tester) async {
        Object? pushedExtra;
        const channelId = 'ch_loading';
        late GoRouter router;

        router = GoRouter(
          initialLocation: '/channels/$channelId',
          routes: [
            GoRoute(
              path: '/channels/:channelId',
              builder: (context, state) =>
                  const ChannelDetailScreen(channelId: channelId),
            ),
            GoRoute(
              path: '/works/:workId',
              builder: (context, state) {
                pushedExtra = state.extra;
                return const SizedBox.shrink();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              channelDetailsProvider(channelId).overrideWith(
                (ref) => const Stream<ChannelDetails>.empty(),
              ),
              nowDisplayingProvider.overrideWith(
                () => _StaticNowDisplayingNotifier(
                  _nowDisplayingSuccess(
                    workId: 'overlay_work',
                    title: 'Overlay Work',
                  ),
                ),
              ),
              nowDisplayingVisibilityProvider.overrideWith(
                () => _StaticNowDisplayingVisibilityNotifier(
                  _visibleNowDisplayingState,
                ),
              ),
              ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
              ff1SupportsShuffleProvider.overrideWithValue(false),
              ff1SupportsLoopProvider.overrideWithValue(false),
            ],
            child: _appWithNowDisplayingOverlay(router: router),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Overlay Work'));
        await tester.pumpAndSettle();

        expect(previousPageTitleFromExtra(pushedExtra), 'Channel');
      },
    );

    testWidgets(
      'playlist detail loading state publishes a fallback overlay title',
      (tester) async {
        Object? pushedExtra;
        const playlistId = 'playlist_loading';
        late GoRouter router;

        router = GoRouter(
          initialLocation: '/playlists/$playlistId',
          routes: [
            GoRoute(
              path: '/playlists/:playlistId',
              builder: (context, state) =>
                  const PlaylistDetailScreen(playlistId: playlistId),
            ),
            GoRoute(
              path: '/works/:workId',
              builder: (context, state) {
                pushedExtra = state.extra;
                return const SizedBox.shrink();
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              playlistDetailsProvider(playlistId).overrideWith(
                () => _StaticPlaylistDetailsNotifier(
                  playlistId,
                  const AsyncValue<PlaylistDetailsState>.loading(),
                ),
              ),
              nowDisplayingProvider.overrideWith(
                () => _StaticNowDisplayingNotifier(
                  _nowDisplayingSuccess(
                    workId: 'overlay_work',
                    title: 'Overlay Work',
                  ),
                ),
              ),
              nowDisplayingVisibilityProvider.overrideWith(
                () => _StaticNowDisplayingVisibilityNotifier(
                  _visibleNowDisplayingState,
                ),
              ),
              ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
              ff1SupportsShuffleProvider.overrideWithValue(false),
              ff1SupportsLoopProvider.overrideWithValue(false),
            ],
            child: _appWithNowDisplayingOverlay(router: router),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Overlay Work'));
        await tester.pumpAndSettle();

        expect(previousPageTitleFromExtra(pushedExtra), 'Playlist');
      },
    );

    testWidgets(
      'work detail not-found state publishes a fallback overlay title',
      (tester) async {
        Object? pushedExtra;
        const workId = 'missing_work';
        late GoRouter router;

        router = GoRouter(
          initialLocation: '/works/$workId',
          routes: [
            GoRoute(
              path: '/works/:workId',
              builder: (context, state) {
                final currentWorkId = state.pathParameters['workId']!;
                if (currentWorkId == 'overlay_work') {
                  pushedExtra = state.extra;
                }
                return WorkDetailScreen(workId: currentWorkId);
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              workDetailStateProvider(workId).overrideWith(
                () => _StaticWorkDetailNotifier(
                  workId,
                  const AsyncValue<WorkDetailData?>.data(null),
                ),
              ),
              workDetailStateProvider('overlay_work').overrideWith(
                () => _StaticWorkDetailNotifier(
                  'overlay_work',
                  const AsyncValue<WorkDetailData?>.data(null),
                ),
              ),
              nowDisplayingProvider.overrideWith(
                () => _StaticNowDisplayingNotifier(
                  _nowDisplayingSuccess(
                    workId: 'overlay_work',
                    title: 'Overlay Work',
                  ),
                ),
              ),
              nowDisplayingVisibilityProvider.overrideWith(
                () => _StaticNowDisplayingVisibilityNotifier(
                  _visibleNowDisplayingState,
                ),
              ),
              ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
              ff1SupportsShuffleProvider.overrideWithValue(false),
              ff1SupportsLoopProvider.overrideWithValue(false),
            ],
            child: _appWithNowDisplayingOverlay(router: router),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Overlay Work'));
        await tester.pumpAndSettle();

        expect(previousPageTitleFromExtra(pushedExtra), 'Work');
      },
    );

    testWidgets(
      'now displaying bar no-ops when tapping the current work',
      (tester) async {
        late GoRouter router;
        var workBuildCount = 0;

        router = GoRouter(
          initialLocation: '/works/work_1',
          routes: [
            GoRoute(
              path: '/works/:workId',
              builder: (context, state) {
                workBuildCount++;
                return const _ScopedTitlePage(title: 'Work 1');
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nowDisplayingProvider.overrideWith(
                () => _StaticNowDisplayingNotifier(
                  _nowDisplayingSuccess(
                    workId: 'work_1',
                    title: 'Overlay Current Work',
                  ),
                ),
              ),
              nowDisplayingVisibilityProvider.overrideWith(
                () => _StaticNowDisplayingVisibilityNotifier(
                  _visibleNowDisplayingState,
                ),
              ),
              ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
              ff1SupportsShuffleProvider.overrideWithValue(false),
              ff1SupportsLoopProvider.overrideWithValue(false),
            ],
            child: _appWithNowDisplayingOverlay(router: router),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Overlay Current Work'));
        await tester.pumpAndSettle();

        expect(router.routerDelegate.state.matchedLocation, '/works/work_1');
        expect(workBuildCount, 1);
      },
    );

    testWidgets(
      'now displaying bar pushes a different work with the current work title',
      (tester) async {
        Object? pushedExtra;
        late GoRouter router;
        final visitedLocations = <String>[];

        router = GoRouter(
          initialLocation: '/works/work_1',
          routes: [
            GoRoute(
              path: '/works/:workId',
              builder: (context, state) {
                final workId = state.pathParameters['workId']!;
                visitedLocations.add(state.matchedLocation);
                if (workId == 'work_2') {
                  pushedExtra = state.extra;
                }
                return _ScopedTitlePage(
                  title: workId == 'work_1' ? 'Work 1' : 'Work 2',
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nowDisplayingProvider.overrideWith(
                () => _StaticNowDisplayingNotifier(
                  _nowDisplayingSuccess(
                    workId: 'work_2',
                    title: 'Overlay Next Work',
                  ),
                ),
              ),
              nowDisplayingVisibilityProvider.overrideWith(
                () => _StaticNowDisplayingVisibilityNotifier(
                  _visibleNowDisplayingState,
                ),
              ),
              ff1WifiControlProvider.overrideWithValue(FakeWifiControl()),
              ff1SupportsShuffleProvider.overrideWithValue(false),
              ff1SupportsLoopProvider.overrideWithValue(false),
            ],
            child: _appWithNowDisplayingOverlay(router: router),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Overlay Next Work'));
        await tester.pumpAndSettle();

        expect(visitedLocations.first, '/works/work_1');
        expect(visitedLocations, contains('/works/work_2'));
        expect(router.routerDelegate.state.matchedLocation, '/works/work_2');
        expect(previousPageTitleFromExtra(pushedExtra), 'Work 1');
      },
    );
  });
}
