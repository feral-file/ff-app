import 'package:app/app/providers/channel_preview_provider.dart';
import 'package:app/app/providers/publisher_section_providers.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_publisher.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/ui/screens/all_channels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeedReadyNotifier extends SeedDatabaseReadyNotifier {
  @override
  bool build() => true;
}

class _SeedNotReadyNotifier extends SeedDatabaseReadyNotifier {
  @override
  bool build() => false;
}

class _StubChannelPreviewNotifier extends ChannelPreviewNotifier {
  _StubChannelPreviewNotifier(super._channelId, this._state);

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
  const orphanWork = PlaylistItem(
    id: 'ch_orphan_work',
    kind: PlaylistItemKind.dp1Item,
    title: 'Orphan Work',
  );

  testWidgets('groups curated channels by publisher', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
          publishersProvider.overrideWithValue(
            AsyncData([
              DP1Publisher(
                id: 10,
                title: 'Publisher Ten',
                createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
                updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
              ),
              DP1Publisher(
                id: 20,
                title: 'Publisher Twenty',
                createdAt: DateTime.fromMicrosecondsSinceEpoch(2),
                updatedAt: DateTime.fromMicrosecondsSinceEpoch(2),
              ),
            ]),
          ),
          channelsByPublisherProvider(10).overrideWithValue(
            const AsyncData([channelOne]),
          ),
          channelsByPublisherProvider(20).overrideWithValue(
            const AsyncData([channelTwo]),
          ),
          channelsByPublisherProvider(null).overrideWithValue(
            const AsyncData(<Channel>[]),
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
        child: const MaterialApp(
          home: Scaffold(
            body: AllChannelsScreen(filter: AllChannelsFilter.curated),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Publisher Ten'), findsOneWidget);
    expect(find.text('Publisher Twenty'), findsOneWidget);
    expect(find.text('Channel One'), findsOneWidget);
    expect(find.text('Channel Two'), findsOneWidget);
  });

  testWidgets('skips empty publisher buckets', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
          publishersProvider.overrideWithValue(
            AsyncData([
              DP1Publisher(
                id: 10,
                title: 'Empty Publisher',
                createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
                updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
              ),
              DP1Publisher(
                id: 20,
                title: 'Filled Publisher',
                createdAt: DateTime.fromMicrosecondsSinceEpoch(2),
                updatedAt: DateTime.fromMicrosecondsSinceEpoch(2),
              ),
            ]),
          ),
          channelsByPublisherProvider(10).overrideWithValue(
            const AsyncData(<Channel>[]),
          ),
          channelsByPublisherProvider(20).overrideWithValue(
            const AsyncData([channelTwo]),
          ),
          channelsByPublisherProvider(null).overrideWithValue(
            const AsyncData(<Channel>[]),
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
        child: const MaterialApp(
          home: Scaffold(
            body: AllChannelsScreen(filter: AllChannelsFilter.curated),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Empty Publisher'), findsNothing);
    expect(find.text('Filled Publisher'), findsOneWidget);
    expect(find.text('Channel Two'), findsOneWidget);
  });

  testWidgets('groups curated channels without a publisher under Other', (
    tester,
  ) async {
    const orphanChannel = Channel(
      id: 'ch_orphan',
      name: 'Orphan Channel',
      description: 'No publisher assigned',
      type: ChannelType.dp1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
          publishersProvider.overrideWithValue(const AsyncData([])),
          channelsByPublisherProvider(null).overrideWithValue(
            const AsyncData([orphanChannel]),
          ),
          channelPreviewProvider('ch_orphan').overrideWith(
            () => _StubChannelPreviewNotifier(
              'ch_orphan',
              ChannelPreviewState.loaded(
                works: const [orphanWork],
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
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Other'), findsOneWidget);
    expect(find.text('Orphan Channel'), findsOneWidget);
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
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
          publishersProvider.overrideWithValue(
            AsyncData([
              DP1Publisher(
                id: 10,
                title: 'Publisher Ten',
                createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
                updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
              ),
            ]),
          ),
          channelsByPublisherProvider(10).overrideWithValue(
            AsyncError<List<Channel>>(
              StateError('channels failed'),
              StackTrace.empty,
            ),
          ),
          channelsByPublisherProvider(null).overrideWithValue(
            const AsyncData(<Channel>[]),
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
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('grouped curated view does not bootstrap flat channels load', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
          publishersProvider.overrideWithValue(
            AsyncData([
              DP1Publisher(
                id: 10,
                title: 'Publisher Ten',
                createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
                updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
              ),
            ]),
          ),
          channelsByPublisherProvider(10).overrideWithValue(
            const AsyncData([channelOne]),
          ),
          channelsByPublisherProvider(null).overrideWithValue(
            const AsyncData(<Channel>[]),
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
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: AllChannelsScreen(filter: AllChannelsFilter.curated),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Publisher Ten'), findsOneWidget);
    expect(find.text('Channel One'), findsOneWidget);
  });
}
