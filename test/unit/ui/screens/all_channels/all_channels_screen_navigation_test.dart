import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/channel_preview_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/ui/screens/all_channels_screen.dart';
import 'package:app/widgets/channels/channel_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('tapping a channel work navigates to work detail', (tester) async {
    const channelId = 'ch_test';
    const workId = 'work_test';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelsProvider(ChannelType.dp1).overrideWith(
            () => _StubChannelsNotifier(
              ChannelType.dp1,
              ChannelsState.loaded(
                channels: const [
                  Channel(
                    id: channelId,
                    name: 'Curated channel',
                    type: ChannelType.dp1,
                  ),
                ],
                hasMore: false,
                cursor: null,
              ),
            ),
          ),
          channelPreviewProvider(channelId).overrideWith(
            () => _StubChannelPreviewNotifier(
              channelId,
              ChannelPreviewState.loaded(
                works: const [
                  PlaylistItem(
                    id: workId,
                    kind: PlaylistItemKind.dp1Item,
                    title: 'Test work',
                  ),
                ],
                hasMore: false,
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/channels/all?filter=curated',
            routes: [
              GoRoute(
                path: '/channels/all',
                builder: (context, state) =>
                    const AllChannelsScreen(filter: AllChannelsFilter.curated),
              ),
              GoRoute(
                path: '/channels/:channelId',
                builder: (context, state) => Scaffold(
                  body: Text('Channel detail ${state.pathParameters['channelId']}'),
                ),
              ),
              GoRoute(
                path: '/works/:workId',
                builder: (context, state) => Scaffold(
                  body: Text('Work detail ${state.pathParameters['workId']}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Avoid pumpAndSettle: some widgets in the tree may schedule animations.
    await tester.pump();

    final row = tester.widget<ChannelListRow>(find.byType(ChannelListRow).first);
    row.onItemTap?.call(
      const PlaylistItem(
        id: workId,
        kind: PlaylistItemKind.dp1Item,
        title: 'Test work',
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Work detail $workId'), findsOneWidget);
    expect(find.textContaining('Channel detail'), findsNothing);
  });
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

  @override
  Future<void> loadMore() async {}
}

