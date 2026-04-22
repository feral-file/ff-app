import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/channel_preview_provider.dart';
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
          channelsProvider(ChannelType.dp1)
              .overrideWith(() => _StubChannelsNotifier(ChannelType.dp1, channelsState)),
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
            AsyncData(const [channelOne]),
          ),
          channelsByPublisherProvider(20).overrideWithValue(
            AsyncData(const [channelTwo]),
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
}
