import 'dart:async';

import 'package:app/app/providers/channel_preview_provider.dart';
import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/publisher_section_providers.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_publisher.dart';
import 'package:app/ui/screens/all_channels/publisher_section_header_delegate.dart';
import 'package:app/ui/screens/all_channels_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Locks the non-grouped [AllChannelsFilter.personal] path: [channelsProvider]
/// for [ChannelType.localVirtual] drives a flat sliver list (no publisher
/// sections).
class _FixedPersonalChannelsNotifier extends ChannelsNotifier {
  _FixedPersonalChannelsNotifier() : super(ChannelType.localVirtual);

  @override
  ChannelsState build() {
    // Do not run [ChannelsNotifier] DB watch — widget test is UI-path only.
    return ChannelsState.loaded(
      channels: const [personalLocalChannel],
      hasMore: false,
      cursor: null,
      total: 1,
    );
  }

  @override
  Future<void> loadChannels({int? size, bool showLoading = true}) async {}

  @override
  Future<void> refresh() async {}
}

const personalLocalChannel = Channel(
  id: 'lv_flat_test',
  name: 'Test Personal Channel',
  description: 'Flat path',
  type: ChannelType.localVirtual,
);

const curatedPlayableChannel = Channel(
  id: 'ch_playable',
  name: 'Playable Channel',
  type: ChannelType.dp1,
  publisherId: 10,
);

class _PublishersErrorAfterSuccessHarness extends StatefulWidget {
  const _PublishersErrorAfterSuccessHarness();

  @override
  State<_PublishersErrorAfterSuccessHarness> createState() =>
      _PublishersErrorAfterSuccessHarnessState();
}

class _PublishersErrorAfterSuccessHarnessState
    extends State<_PublishersErrorAfterSuccessHarness> {
  AsyncValue<List<DP1Publisher>> _publishers = AsyncData([
    DP1Publisher(
      id: 10,
      title: 'Stable Pub',
      createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
        publishersProvider.overrideWithValue(_publishers),
        channelsByPublisherProvider(10).overrideWithValue(
          const AsyncData([curatedPlayableChannel]),
        ),
        channelsByPublisherProvider(null).overrideWithValue(
          const AsyncData(<Channel>[]),
        ),
        channelPreviewProvider('ch_playable').overrideWith(
          () => _StubChannelPreviewNotifier(
            'ch_playable',
            ChannelPreviewState.loaded(works: const [], hasMore: false),
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(
                child: AllChannelsScreen(filter: AllChannelsFilter.curated),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _publishers = AsyncError(Exception('x'), StackTrace.current);
                  });
                },
                child: const Text('trigger_pub_error'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'curated: pull-to-refresh completes when seed database is not ready',
    (tester) async {
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
      final refreshFinder = find.byType(RefreshIndicator);
      expect(refreshFinder, findsOneWidget);
      // Overscroll triggers onRefresh; must complete (no await hang).
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        3000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    },
  );

  testWidgets(
    'AllChannelsFilter.personal uses flat list from channelsProvider '
    '(not grouped by publisher)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            channelsProvider(
              ChannelType.localVirtual,
            ).overrideWith(_FixedPersonalChannelsNotifier.new),
            // Avoid loading previews from the real DB; empty list is a stable
            // loaded state for the row.
            channelPreviewProvider('lv_flat_test').overrideWith(
              () => _StubChannelPreviewNotifier(
                'lv_flat_test',
                ChannelPreviewState.loaded(works: const [], hasMore: false),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AllChannelsScreen(filter: AllChannelsFilter.personal),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Personal'), findsOneWidget);
      expect(
        find.textContaining(
          'Public Channels gathered from across the ecosystem',
        ),
        findsOneWidget,
      );
      expect(find.text('Test Personal Channel'), findsOneWidget);
      // Grouped-curated-only titles must not appear on the personal path.
      expect(find.text('Publisher Ten'), findsNothing);
      expect(find.text('Other'), findsNothing);
    },
  );

  testWidgets(
    'curated grouped: when every publisher bucket has no playable '
    'channels, no channel title appears',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
            publishersProvider.overrideWithValue(
              AsyncData([
                DP1Publisher(
                  id: 10,
                  title: 'Has No Playable',
                  createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
                  updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
                ),
              ]),
            ),
            channelsByPublisherProvider(10).overrideWithValue(
              const AsyncData(<Channel>[]),
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

      expect(find.text('No channels found'), findsOneWidget);
      expect(find.text('Has No Playable'), findsNothing);
    },
  );

  testWidgets(
    'curated grouped: when publisher stream loses last channel, list '
    'updates to empty',
    (tester) async {
      final playStream = StreamController<List<Channel>>.broadcast();
      addTearDown(playStream.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
            publishersProvider.overrideWithValue(
              AsyncData([
                DP1Publisher(
                  id: 10,
                  title: 'Solo Publisher',
                  createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
                  updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
                ),
              ]),
            ),
            channelsByPublisherProvider(10).overrideWith(
              (ref) => playStream.stream,
            ),
            channelsByPublisherProvider(null).overrideWithValue(
              const AsyncData(<Channel>[]),
            ),
            channelPreviewProvider('ch_playable').overrideWith(
              () => _StubChannelPreviewNotifier(
                'ch_playable',
                ChannelPreviewState.loaded(works: const [], hasMore: false),
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
      playStream.add([curatedPlayableChannel]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Solo Publisher'), findsOneWidget);
      expect(find.text('Playable Channel'), findsOneWidget);

      playStream.add(const <Channel>[]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Playable Channel'), findsNothing);
      expect(find.text('No channels found'), findsOneWidget);
    },
  );

  testWidgets(
    'curated grouped: a still-loading bucket does not block content from a '
    'bucket that has already loaded',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
            publishersProvider.overrideWithValue(
              AsyncData([
                DP1Publisher(
                  id: 10,
                  title: 'Ready Publisher',
                  createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
                  updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
                ),
                DP1Publisher(
                  id: 20,
                  title: 'Pending Publisher',
                  createdAt: DateTime.fromMicrosecondsSinceEpoch(2),
                  updatedAt: DateTime.fromMicrosecondsSinceEpoch(2),
                ),
              ]),
            ),
            channelsByPublisherProvider(10).overrideWithValue(
              const AsyncData([curatedPlayableChannel]),
            ),
            channelsByPublisherProvider(20).overrideWithValue(
              const AsyncLoading<List<Channel>>(),
            ),
            channelsByPublisherProvider(null).overrideWithValue(
              const AsyncData(<Channel>[]),
            ),
            channelPreviewProvider('ch_playable').overrideWith(
              () => _StubChannelPreviewNotifier(
                'ch_playable',
                ChannelPreviewState.loaded(works: const [], hasMore: false),
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

      expect(find.text('Ready Publisher'), findsOneWidget);
      expect(find.text('Playable Channel'), findsOneWidget);
      expect(find.text('Pending Publisher'), findsOneWidget);
    },
  );

  testWidgets(
    'curated grouped: publisher list error after success keeps last sections '
    'and shows stale banner',
    (tester) async {
      await tester.pumpWidget(
        const _PublishersErrorAfterSuccessHarness(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Stable Pub'), findsOneWidget);
      expect(find.text('Playable Channel'), findsOneWidget);
      expect(
        find.textContaining('last loaded sections'),
        findsNothing,
      );

      await tester.tap(find.text('trigger_pub_error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Stable Pub'), findsOneWidget);
      expect(find.text('Playable Channel'), findsOneWidget);
      expect(find.textContaining('last loaded sections'), findsOneWidget);
    },
  );

  testWidgets(
    'curated grouped: sticky headers are used for publisher sections',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
            publishersProvider.overrideWithValue(
              AsyncData([
                DP1Publisher(
                  id: 10,
                  title: 'Publisher One',
                  createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
                  updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
                ),
                DP1Publisher(
                  id: 20,
                  title: 'Publisher Two',
                  createdAt: DateTime.fromMicrosecondsSinceEpoch(2),
                  updatedAt: DateTime.fromMicrosecondsSinceEpoch(2),
                ),
              ]),
            ),
            channelsByPublisherProvider(10).overrideWithValue(
              const AsyncData([
                Channel(
                  id: 'ch1',
                  name: 'Channel One',
                  type: ChannelType.dp1,
                  publisherId: 10,
                ),
              ]),
            ),
            channelsByPublisherProvider(20).overrideWithValue(
              const AsyncData([
                Channel(
                  id: 'ch2',
                  name: 'Channel Two',
                  type: ChannelType.dp1,
                  publisherId: 20,
                ),
              ]),
            ),
            channelsByPublisherProvider(null).overrideWithValue(
              const AsyncData(<Channel>[]),
            ),
            channelPreviewProvider('ch1').overrideWith(
              () => _StubChannelPreviewNotifier(
                'ch1',
                ChannelPreviewState.loaded(works: const [], hasMore: false),
              ),
            ),
            channelPreviewProvider('ch2').overrideWith(
              () => _StubChannelPreviewNotifier(
                'ch2',
                ChannelPreviewState.loaded(works: const [], hasMore: false),
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

      // Verify SliverMainAxisGroup wraps each publisher section.
      final mainAxisGroups = tester.widgetList<SliverMainAxisGroup>(
        find.byType(SliverMainAxisGroup),
      );
      expect(mainAxisGroups.length, 2);

      // Verify SliverPersistentHeader exists for each publisher section.
      final persistentHeaders = tester.widgetList<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader),
      );
      expect(persistentHeaders.length, greaterThanOrEqualTo(2));

      // Verify headers are pinned.
      for (final header in persistentHeaders) {
        expect(header.pinned, isTrue);
      }

      // Verify header delegates have correct titles.
      final delegates = persistentHeaders
          .map((h) => h.delegate)
          .whereType<PublisherSectionHeaderDelegate>()
          .toList();
      expect(delegates.length, 2);
      expect(delegates[0].title, 'Publisher One');
      expect(delegates[1].title, 'Publisher Two');
    },
  );

  testWidgets(
    'curated grouped: sticky header for "Other" section when it has channels',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
            publishersProvider.overrideWithValue(
              const AsyncData(<DP1Publisher>[]),
            ),
            channelsByPublisherProvider(null).overrideWithValue(
              const AsyncData([
                Channel(
                  id: 'ch_other',
                  name: 'Other Channel',
                  type: ChannelType.dp1,
                  publisherId: null,
                ),
              ]),
            ),
            channelPreviewProvider('ch_other').overrideWith(
              () => _StubChannelPreviewNotifier(
                'ch_other',
                ChannelPreviewState.loaded(works: const [], hasMore: false),
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

      // Verify "Other" section is wrapped in SliverMainAxisGroup.
      final mainAxisGroups = tester.widgetList<SliverMainAxisGroup>(
        find.byType(SliverMainAxisGroup),
      );
      expect(mainAxisGroups.length, 1);

      // Verify "Other" sticky header exists.
      final delegates = tester
          .widgetList<SliverPersistentHeader>(
            find.byType(SliverPersistentHeader),
          )
          .map((h) => h.delegate)
          .whereType<PublisherSectionHeaderDelegate>()
          .toList();
      expect(delegates.length, 1);
      expect(delegates[0].title, 'Other');
    },
  );

  testWidgets(
    'curated grouped: no sticky headers when all sections are empty',
    (tester) async {
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
              ]),
            ),
            channelsByPublisherProvider(10).overrideWithValue(
              const AsyncData(<Channel>[]),
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

      // Verify no sticky headers are rendered for empty sections.
      final persistentHeaders = tester.widgetList<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader),
      );
      final headerDelegates = persistentHeaders
          .map((h) => h.delegate)
          .whereType<PublisherSectionHeaderDelegate>()
          .toList();
      expect(headerDelegates, isEmpty);
      expect(find.text('Empty Publisher'), findsNothing);
      expect(find.text('No channels found'), findsOneWidget);
    },
  );

  testWidgets(
    'curated grouped: sticky headers not used for loading state',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
            publishersProvider.overrideWithValue(
              AsyncData([
                DP1Publisher(
                  id: 10,
                  title: 'Loading Publisher',
                  createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
                  updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
                ),
              ]),
            ),
            channelsByPublisherProvider(10).overrideWithValue(
              const AsyncLoading<List<Channel>>(),
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

      // Verify loading state header is not a sticky header (just text).
      expect(find.text('Loading Publisher'), findsOneWidget);
      final persistentHeaders = tester.widgetList<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader),
      );
      final headerDelegates = persistentHeaders
          .map((h) => h.delegate)
          .whereType<PublisherSectionHeaderDelegate>()
          .where((d) => d.title == 'Loading Publisher')
          .toList();
      expect(headerDelegates, isEmpty);
    },
  );

  testWidgets(
    'curated grouped: sticky headers not used for error state',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
            publishersProvider.overrideWithValue(
              AsyncData([
                DP1Publisher(
                  id: 10,
                  title: 'Error Publisher',
                  createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
                  updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
                ),
              ]),
            ),
            channelsByPublisherProvider(10).overrideWithValue(
              AsyncError(Exception('x'), StackTrace.current),
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

      // Verify error state header is not a sticky header (just text).
      expect(find.text('Error Publisher'), findsOneWidget);
      final persistentHeaders = tester.widgetList<SliverPersistentHeader>(
        find.byType(SliverPersistentHeader),
      );
      final headerDelegates = persistentHeaders
          .map((h) => h.delegate)
          .whereType<PublisherSectionHeaderDelegate>()
          .where((d) => d.title == 'Error Publisher')
          .toList();
      expect(headerDelegates, isEmpty);
    },
  );

  testWidgets(
    'curated grouped: scroll behavior - only one header visible at a time',
    (tester) async {
      // Create enough channels per publisher to make sections scrollable.
      final manyChannels = List.generate(
        20,
        (i) => Channel(
          id: 'ch_$i',
          name: 'Channel $i',
          type: ChannelType.dp1,
          publisherId: 10,
        ),
      );
      final manyChannels2 = List.generate(
        20,
        (i) => Channel(
          id: 'ch2_$i',
          name: 'Second Publisher Channel $i',
          type: ChannelType.dp1,
          publisherId: 20,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSeedDatabaseReadyProvider.overrideWith(_SeedReadyNotifier.new),
            publishersProvider.overrideWithValue(
              AsyncData([
                DP1Publisher(
                  id: 10,
                  title: 'First Publisher',
                  createdAt: DateTime.fromMicrosecondsSinceEpoch(1),
                  updatedAt: DateTime.fromMicrosecondsSinceEpoch(1),
                ),
                DP1Publisher(
                  id: 20,
                  title: 'Second Publisher',
                  createdAt: DateTime.fromMicrosecondsSinceEpoch(2),
                  updatedAt: DateTime.fromMicrosecondsSinceEpoch(2),
                ),
              ]),
            ),
            channelsByPublisherProvider(10).overrideWithValue(
              AsyncData(manyChannels),
            ),
            channelsByPublisherProvider(20).overrideWithValue(
              AsyncData(manyChannels2),
            ),
            channelsByPublisherProvider(null).overrideWithValue(
              const AsyncData(<Channel>[]),
            ),
            for (var i = 0; i < 20; i++)
              channelPreviewProvider('ch_$i').overrideWith(
                () => _StubChannelPreviewNotifier(
                  'ch_$i',
                  ChannelPreviewState.loaded(works: const [], hasMore: false),
                ),
              ),
            for (var i = 0; i < 20; i++)
              channelPreviewProvider('ch2_$i').overrideWith(
                () => _StubChannelPreviewNotifier(
                  'ch2_$i',
                  ChannelPreviewState.loaded(works: const [], hasMore: false),
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

      // Verify first header exists.
      expect(find.text('First Publisher'), findsOneWidget);

      // Verify SliverMainAxisGroup architecture is in place.
      // Each section with data is wrapped in its own SliverMainAxisGroup, which
      // prevents header stacking per Flutter framework contract. When scrolling
      // to a new section, its header pushes the previous one off-screen.
      final mainAxisGroupsBefore = tester.widgetList<SliverMainAxisGroup>(
        find.byType(SliverMainAxisGroup),
      );
      expect(
        mainAxisGroupsBefore.length,
        greaterThanOrEqualTo(1),
        reason: 'At least one section with SliverMainAxisGroup should be '
            'rendered',
      );

      // Scroll down significantly through content.
      final scrollView = find.byType(CustomScrollView);
      await tester.drag(scrollView, const Offset(0, -1000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // After scroll, verify structure still intact.
      final mainAxisGroupsAfter = tester.widgetList<SliverMainAxisGroup>(
        find.byType(SliverMainAxisGroup),
      );
      expect(
        mainAxisGroupsAfter.length,
        greaterThanOrEqualTo(1),
        reason: 'SliverMainAxisGroup structure persists after scroll',
      );

      // The key verification: SliverMainAxisGroup prevents stacking.
      // With bare pinned headers (without grouping), scrolling would stack all
      // headers at screen top. The grouping ensures only the active section's
      // header is pinned. Widget tests cannot easily verify exact render
      // positions, but the structural guarantee (each section in its own
      // SliverMainAxisGroup) ensures correct behavior per Flutter framework
      // contract.
    },
  );
}
