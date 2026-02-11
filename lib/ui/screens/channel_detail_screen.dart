import 'package:app/app/providers/channel_detail_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/bottom_spacing.dart';
import 'package:app/widgets/channel_item.dart';
import 'package:app/widgets/error_view.dart';
import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/playlist/playlist_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Channel detail screen.
/// Shows details and content for a specific channel.
class ChannelDetailScreen extends ConsumerWidget {
  /// Creates a ChannelDetailScreen.
  const ChannelDetailScreen({
    required this.channelId,
    super.key,
  });

  /// The channel ID to display.
  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> onRefresh() async {
      ref.invalidate(channelDetailsProvider(channelId));
    }

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: MainAppBar(
        backTitle: 'Channels',
        backgroundColor: AppColor.auGreyBackground,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: onRefresh,
          backgroundColor: AppColor.primaryBlack,
          color: AppColor.white,
          child: ref
              .watch(channelDetailsProvider(channelId))
              .when(
                loading: () => const LoadingView(),
                error: (error, _) => ErrorView(
                  error:
                      'We couldn’t load this channel. Check your connection, then Retry.',
                  onRetry: () => onRefresh(),
                ),
                data: (details) {
                  final channel = details.channel;
                  final playlists = details.playlists;
                  if (channel == null) {
                    return Center(
                      child: Text(
                        'Channel not found',
                        style: AppTypography.body(context).grey,
                      ),
                    );
                  }

                  return CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(height: LayoutConstants.space6),
                      ),
                      SliverToBoxAdapter(
                        child: ChannelHeader(
                          channelId: channel.id,
                          channelTitle: channel.name,
                          channelSummary: channel.description,
                          clickable: false,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(height: LayoutConstants.space6),
                      ),
                      if (playlists.isEmpty)
                        SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    LayoutConstants.pageHorizontalDefault,
                              ),
                              child: Text(
                                'This channel has no playlists.',
                                style: AppTypography.body(context).grey,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: playlists.length,
                          itemBuilder: (context, index) => PlaylistRowItem(
                            playlist: playlists[index],
                            onItemTap: (item) {
                              context.push('${Routes.works}/${item.id}');
                            },
                          ),
                        ),
                      const SliverToBoxAdapter(child: BottomSpacing()),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}
