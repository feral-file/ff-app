import 'package:app/app/providers/publisher_section_providers.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/app/utils/all_playlists_publisher_layout.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SeedTrue extends SeedDatabaseReadyNotifier {
  @override
  bool build() => true;
}

class _SeedFalse extends SeedDatabaseReadyNotifier {
  @override
  bool build() => false;
}

void main() {
  const playlistsTwoPublishers = [
    Playlist(
      id: 'pl_1',
      name: 'P1',
      type: PlaylistType.dp1,
      channelId: 'ch_a',
      itemCount: 1,
    ),
    Playlist(
      id: 'pl_2',
      name: 'P2',
      type: PlaylistType.dp1,
      channelId: 'ch_b',
      itemCount: 1,
    ),
  ];

  final channelMap = {
    'ch_a': const Channel(
      id: 'ch_a',
      name: 'Channel A',
      type: ChannelType.dp1,
      publisherId: 1,
    ),
    'ch_b': const Channel(
      id: 'ch_b',
      name: 'Channel B',
      type: ChannelType.dp1,
      publisherId: 2,
    ),
  };

  testWidgets('lookup streams + seed ready: GROUPED for two publishers', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedTrue.new),
          publisherTitlesMapProvider.overrideWith(
            (ref) => Stream.value({1: 'Publisher One', 2: 'Publisher Two'}),
          ),
          allChannelsByIdMapProvider.overrideWith(
            (ref) => Stream.value(channelMap),
          ),
        ],
        child: const MaterialApp(
          home: _LayoutLabel(
            channelScoped: false,
            playlists: playlistsTwoPublishers,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('GROUPED'), findsOneWidget);
  });

  testWidgets('seed DB not ready: FLAT even when lookups have data', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedFalse.new),
          publisherTitlesMapProvider.overrideWith(
            (ref) => Stream.value({1: 'Publisher One', 2: 'Publisher Two'}),
          ),
          allChannelsByIdMapProvider.overrideWith(
            (ref) => Stream.value(channelMap),
          ),
        ],
        child: const MaterialApp(
          home: _LayoutLabel(
            channelScoped: false,
            playlists: playlistsTwoPublishers,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FLAT'), findsOneWidget);
  });

  testWidgets('channel-scoped flag: FLAT', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSeedDatabaseReadyProvider.overrideWith(_SeedTrue.new),
          publisherTitlesMapProvider.overrideWith(
            (ref) => Stream.value({1: 'Publisher One', 2: 'Publisher Two'}),
          ),
          allChannelsByIdMapProvider.overrideWith(
            (ref) => Stream.value(channelMap),
          ),
        ],
        child: const MaterialApp(
          home: _LayoutLabel(
            channelScoped: true,
            playlists: playlistsTwoPublishers,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('FLAT'), findsOneWidget);
  });
}

/// Mirrors how All Playlists combines `ref.watch` outputs with
/// `resolveAllPlaylistsPublisherLayout`.
class _LayoutLabel extends ConsumerWidget {
  const _LayoutLabel({
    required this.channelScoped,
    required this.playlists,
  });

  final bool channelScoped;
  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seedReady = ref.watch(isSeedDatabaseReadyProvider);
    final publisherAsync = ref.watch(publisherTitlesMapProvider);
    final channelAsync = ref.watch(allChannelsByIdMapProvider);
    final layout = resolveAllPlaylistsPublisherLayout(
      isChannelScoped: channelScoped,
      seedDatabaseReady: seedReady,
      publisherAsync: publisherAsync,
      channelAsync: channelAsync,
      playlists: playlists,
    );
    return Text(layout.useSectionHeaders ? 'GROUPED' : 'FLAT');
  }
}
