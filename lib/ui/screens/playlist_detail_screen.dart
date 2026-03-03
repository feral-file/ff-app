import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/playlist_details_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_intent.dart';
import 'package:app/infra/database/converters.dart' show DatabaseConverters;
import 'package:app/infra/database/database_provider.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/ff_display_button.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_details_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Playlist detail screen.
/// Shows details and works for a specific playlist.
/// Note: Exhibition/Season/Program are playlist roles (UI chrome),
/// not separate domain objects.
class PlaylistDetailScreen extends ConsumerStatefulWidget {
  /// Creates a PlaylistDetailScreen.
  const PlaylistDetailScreen({
    required this.playlistId,
    super.key,
  });

  /// The playlist ID to display.
  final String playlistId;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * 0.8) {
      ref.read(playlistDetailsProvider(widget.playlistId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(playlistDetailsProvider(widget.playlistId));

    final state = detailsAsync.hasValue ? detailsAsync.value : null;
    final hasPlaylist = state?.playlist != null && state?.items != null;

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: MainAppBar(
        backTitle: 'Playlists',
        backgroundColor: AppColor.auGreyBackground,
        actions: [
          if (hasPlaylist)
            FFDisplayButton(
              onDeviceSelected: (device) async {
                final current = ref
                    .read(playlistDetailsProvider(widget.playlistId))
                    .value;
                if (current?.playlist == null || current?.items == null) {
                  return;
                }
                final canvas = ref.read(canvasClientServiceV2Provider);

                final database = ref.read(databaseServiceProvider);

                final allItems = await database.getPlaylistItems(
                  widget.playlistId,
                );
                final dp1 = DatabaseConverters.playlistAndItemsToDP1Playlist(
                  current!.playlist!,
                  allItems,
                );
                await canvas.castPlaylist(
                  device,
                  dp1,
                  DP1Intent.displayNow(),
                  usingUrl: false,
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: detailsAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error:
                'We couldn’t load this playlist. Check your connection, then Retry.',
            onRetry: () =>
                ref.invalidate(playlistDetailsProvider(widget.playlistId)),
          ),
          data: (state) {
            final playlist = state.playlist;
            final items = state.items;
            if (playlist == null) {
              return Center(
                child: Text(
                  'Playlist not found',
                  style: AppTypography.body(context).grey,
                ),
              );
            }

            // Playlist (domain) uses name; channel for subtitle
            final channelId = playlist.channelId;
            final channelAsync = channelId == null
                ? const AsyncValue<Channel?>.data(null)
                : ref.watch(channelByIdProvider(channelId));

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: channelAsync.when(
                    loading: () => PlaylistDetailsHeader(
                      title: playlist.name,
                      total: state.total,
                    ),
                    error: (_, _) => PlaylistDetailsHeader(
                      title: playlist.name,
                      total: state.total,
                    ),
                    data: (channel) => PlaylistDetailsHeader(
                      title: playlist.name,
                      total: state.total,
                      subtitle: channel?.name,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: LayoutConstants.space6),
                ),
                if (items.isEmpty)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: LayoutConstants.pageHorizontalDefault,
                        ),
                        child: Text(
                          'This playlist is empty.',
                          style: AppTypography.body(context).grey,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: LayoutConstants.pageHorizontalDefault,
                    ),
                    sliver: UIHelper.worksSliverGrid(
                      works: items,
                      onItemTap: (item) =>
                          context.push('${Routes.works}/${item.id}'),
                    ),
                  ),
                if (state.isLoadingMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(LayoutConstants.space4),
                      child: const Center(child: LoadingWidget()),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
