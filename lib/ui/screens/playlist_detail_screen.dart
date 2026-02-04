import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/providers/playlist_details_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_details_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Playlist detail screen.
/// Shows details and works for a specific playlist.
/// Note: Exhibition/Season/Program are playlist roles (UI chrome),
/// not separate domain objects.
class PlaylistDetailScreen extends ConsumerWidget {
  /// Creates a PlaylistDetailScreen.
  const PlaylistDetailScreen({
    required this.playlistId,
    super.key,
  });

  /// The playlist ID to display.
  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(playlistDetailsProvider(playlistId));

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: AppBar(
        backgroundColor: AppColor.auGreyBackground,
        title: Text(
          'Playlist',
          style: AppTypography.h4(context).white,
        ),
      ),
      body: SafeArea(
        child: detailsAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            error: 'We couldn’t load this playlist. Check your connection, then Retry.',
            onRetry: () => ref.invalidate(playlistDetailsProvider(playlistId)),
          ),
          data: (details) {
            final playlist = details.playlist;
            final items = details.items;
            if (playlist == null) {
              return Center(
                child: Text(
                  'Playlist not found',
                  style: AppTypography.body(context).grey,
                ),
              );
            }

            // PlaylistData uses title; channel for subtitle
            final channelId = playlist.channelId;
            final AsyncValue<Channel?> channelAsync = channelId == null
                ? const AsyncValue<Channel?>.data(null)
                : ref.watch(channelByIdProvider(channelId));

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: channelAsync.when(
                    loading: () => PlaylistDetailsHeader(
                      title: playlist.title,
                      total: items.length,
                    ),
                    error: (_, __) => PlaylistDetailsHeader(
                      title: playlist.title,
                      total: items.length,
                    ),
                    data: (channel) => PlaylistDetailsHeader(
                      title: playlist.title,
                      total: items.length,
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
                          context.go('${Routes.works}/${item.id}'),
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
