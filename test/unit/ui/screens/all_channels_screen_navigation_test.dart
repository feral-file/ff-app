import 'package:app/app/providers/channel_preview_provider.dart';
import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/publisher_section_providers.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/ui/screens/all_channels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _SeedReadyNotifier extends SeedDatabaseReadyNotifier {
  @override
  bool build() => true;
}

class _SeedNotReadyNotifier extends SeedDatabaseReadyNotifier {
  @override
  bool build() => false;
}

class _StubChannelsNotifier extends ChannelsNotifier {
  _StubChannelsNotifier(super.type, this._state);

  final ChannelsState _state;

  @override
  ChannelsState build() => _state;

  @override
  Future<void> loadChannels({int? size, bool showLoading = true}) async {}

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}
}

class _CountingChannelsNotifier extends ChannelsNotifier {
  _CountingChannelsNotifier(super.type, this._state, this.onLoadChannels);

  final ChannelsState _state;
  final VoidCallback onLoadChannels;

  @override
  ChannelsState build() => _state;

  @override
  Future<void> loadChannels({int? size, bool showLoading = true}) async {
    onLoadChannels();
  }

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}
}

class _StubChannelPreviewNotifier extends ChannelPreviewNotifier {
  _StubChannelPreviewNotifier(super.channelId, this._state);

  final ChannelPreviewState _state;

  @override
  ChannelPreviewState build() => _state;

  @override
  Future<void> load({int? limit, int? offset, bool showLoading = true}) async {}
}

void main() {
  const channelOne = Channel(
    id: 'ch_one',
    name: 'Channel One',
    description: 'First publisher channel',
    type: ChannelType.dp1,
    publisherId: 10,
  );
  const channelTwo = Channel(
    id: 'ch_two',
    name: 'Channel Two',
    description: 'Second publisher channel',
    type: ChannelType.dp1,
    publisherId: 20,
  );
  const workOne = PlaylistItem(
    id: 'ch_one_work',
    kind: PlaylistItemKind.dp1Item,
    title: 'Work One',
  );
  const workTwo = PlaylistItem(
    id: 'ch_two_work',
    kind: PlaylistItemKind.dp1Item,
    title: 'Work Two',
  );

  final channelsState = ChannelsState.loaded(
    channels: const [channelOne, channelTwo],
    hasMore: false,
    cursor: null,
  );

  testWidgets('groups curated channels by publisher', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/channels/all',
      routes: [
        GoRoute(
          path: '/channels/all',
          builder: (context, state) => const Scaffold(
            body: AllChannelsScreen(filter: AllChannelsFilter.curated),
          ),
        ),
        GoRoute(
          path: '/works/:workId',
          builder: (context, state) => Scaffold(
            body: Text('work ${state.pathParameters['workId']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
          channelsProvider(ChannelType.dp1).overrideWith(
            () => _StubChannelsNotifier(ChannelType.dp1, channelsState),
          ),
          publishersProvider.overrideWithValue(
            AsyncData([
              PublisherData(
                id: 10,
                title: 'Publisher Ten',
                createdAtUs: BigInt.from(1),
                updatedAtUs: BigInt.from(1),
              ),
              PublisherData(
                id: 20,
                title: 'Publisher Twenty',
                createdAtUs: BigInt.from(2),
                updatedAtUs: BigInt.from(2),
              ),
            ]),
          ),
          channelsByPublisherProvider(10).overrideWithValue(
            const AsyncData([channelOne]),
          ),
          channelsByPublisherProvider(20).overrideWithValue(
            const AsyncData([channelTwo]),
          ),
          channelPreviewProvider('ch_one').overrideWith(
            () => _StubChannelPreviewNotifier(
              'ch_one',
              ChannelPreviewState.loaded(
                works: const [workOne],
                hasMore: false,
              ),
            ),
          ),
          channelPreviewProvider('ch_two').overrideWith(
            () => _StubChannelPreviewNotifier(
              'ch_two',
              ChannelPreviewState.loaded(
                works: const [workTwo],
                hasMore: false,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pump();

    expect(find.text('Publisher Ten'), findsOneWidget);
    expect(find.text('Publisher Twenty'), findsOneWidget);
    expect(find.text('Channel One'), findsOneWidget);
    expect(find.text('Channel Two'), findsOneWidget);
  });

  testWidgets('shows loading while the seed DB is not ready', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedNotReadyNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AllChannelsScreen(filter: AllChannelsFilter.curated),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('No channels found'), findsNothing);
    expect(find.text('Loading...'), findsWidgets);
  });

  testWidgets('retry rebuilds grouped curated stream providers', (
    tester,
  ) async {
    var publishersBuilds = 0;
    var channelsBuilds = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
          channelsProvider(ChannelType.dp1).overrideWith(
            () => _StubChannelsNotifier(
              ChannelType.dp1,
              ChannelsState.loaded(
                channels: const [],
                hasMore: false,
                cursor: null,
              ),
            ),
          ),
          publishersProvider.overrideWith((ref) {
            publishersBuilds++;
            return Stream.value(
              [
                PublisherData(
                  id: 10,
                  title: 'Publisher Ten',
                  createdAtUs: BigInt.from(1),
                  updatedAtUs: BigInt.from(1),
                ),
              ],
            );
          }),
          channelsByPublisherProvider(10).overrideWith((ref) {
            channelsBuilds++;
            return Stream.error(StateError('channels failed'));
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AllChannelsScreen(filter: AllChannelsFilter.curated),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('Retry'), findsOneWidget);
    expect(publishersBuilds, 1);
    expect(channelsBuilds, 1);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(publishersBuilds, greaterThan(1));
    expect(channelsBuilds, greaterThan(1));
  });

  testWidgets('grouped curated view does not bootstrap flat channels load', (
    tester,
  ) async {
    var loadChannelsCalls = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
          channelsProvider(ChannelType.dp1).overrideWith(
            () => _CountingChannelsNotifier(
              ChannelType.dp1,
              ChannelsState.loaded(
                channels: const [],
                hasMore: false,
                cursor: null,
              ),
              () => loadChannelsCalls++,
            ),
          ),
          publishersProvider.overrideWith((ref) {
            return Stream.value([
              PublisherData(
                id: 10,
                title: 'Publisher Ten',
                createdAtUs: BigInt.from(1),
                updatedAtUs: BigInt.from(1),
              ),
            ]);
          }),
          channelsByPublisherProvider(10).overrideWith((ref) {
            return Stream.value(const [channelOne]);
          }),
          channelPreviewProvider('ch_one').overrideWith(
            () => _StubChannelPreviewNotifier(
              'ch_one',
              ChannelPreviewState.loaded(
                works: const [workOne],
                hasMore: false,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AllChannelsScreen(filter: AllChannelsFilter.curated),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(loadChannelsCalls, 0);
    expect(find.text('Publisher Ten'), findsOneWidget);
    expect(find.text('Channel One'), findsOneWidget);
  });
}
