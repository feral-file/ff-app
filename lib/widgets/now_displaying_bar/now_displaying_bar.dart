import 'dart:async';

import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'collapsed_now_playing_bar.dart';
import 'expanded_now_playing_bar.dart';
import 'sleep_mode_indicator.dart';
import 'top_line.dart';
import 'two_stop_draggable_sheet.dart';

/// Global bottom overlay for FF1 Now Displaying.
///
/// This widget is UI-only and reads data from [nowDisplayingProvider].
/// [router] is required so the overlay can navigate without relying on
/// [BuildContext] (the overlay is built outside the Navigator subtree).
class NowDisplayingBarOverlay extends ConsumerWidget {
  const NowDisplayingBarOverlay({
    required this.router,
    super.key,
  });

  final GoRouter router;

  double get _collapsedHeight =>
      LayoutConstants.nowDisplayingBarCollapsedHeight;

  double get _expandedHeight => LayoutConstants.nowDisplayingBarExpandedHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shouldShow = ref.watch(
      nowDisplayingVisibilityProvider.select((s) => s.shouldShow),
    );
    final status = ref.watch(nowDisplayingProvider);

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: LayoutConstants.pageHorizontalDefault,
      right: LayoutConstants.pageHorizontalDefault,
      bottom:
          bottomPadding + LayoutConstants.nowDisplayingBarOverlayBottomOffset,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: _expandedHeight,
        ),
        child: _NowDisplayingBarCard(
          collapsedHeight: _collapsedHeight,
          expandedHeight: _expandedHeight,
          status: status,
          router: router,
        ),
      ),
    );
  }
}

class _NowDisplayingBarCard extends ConsumerWidget {
  const _NowDisplayingBarCard({
    required this.collapsedHeight,
    required this.expandedHeight,
    required this.status,
    required this.router,
  });

  final double collapsedHeight;
  final double expandedHeight;
  final NowDisplayingStatus status;
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (status) {
      case NoDevicePaired():
        return const _NowPlayingStatusBar(
          text: 'Pair an FF1 to start playing from any screen',
        );
      case DeviceDisconnected(:final device):
        final name = device.name.isNotEmpty ? device.name : 'FF1';
        return _NowPlayingStatusBar(
          text: '$name is offline or disconnected',
        );
      case LoadingNowDisplaying():
        return const _NowPlayingStatusBar(
          text: 'Loading now displaying…',
        );
      case NowDisplayingError():
        return const _NowPlayingStatusBar(
          text: 'We couldn’t load now displaying',
        );
      case NowDisplayingSuccess(:final object):
        if (object is! DP1NowDisplayingObject) {
          return const SizedBox.shrink();
        }
        if (object.isSleeping) {
          return _NowPlayingSleepBar(
            deviceName: object.connectedDevice.name,
          );
        }

        final minSize = collapsedHeight / expandedHeight;
        final topicId = object.connectedDevice.topicId;
        final wifiControl = ref.read(ff1WifiControlProvider);

        return SizedBox(
          height: expandedHeight,
          child: TwoStopDraggableSheet(
            key: nowDisplayingSheetKey,
            minSize: minSize,
            maxSize: 1,
            collapsedBuilder: (context, _) {
              return CollapsedNowPlayingBar(
                playingObject: object,
                onTap: () => router.push(Routes.nowDisplaying),
              );
            },
            expandedBuilder: (context, scrollController) {
              return ExpandedNowPlayingBar(
                playingObject: object,
                onItemTap: (index) {
                  unawaited(
                    wifiControl.moveToArtwork(
                      topicId: topicId,
                      index: index,
                    ),
                  );
                },
              );
            },
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _NowPlayingCardContainer extends StatelessWidget {
  const _NowPlayingCardContainer({
    required this.child,
    this.backgroundColor,
  });

  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? PrimitivesTokens.colorsBlack,
        borderRadius: BorderRadius.circular(
          LayoutConstants.nowDisplayingBarCornerRadius,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: LayoutConstants.nowDisplayingBarPaddingTop,
          left: LayoutConstants.nowDisplayingBarPaddingHorizontal,
          right: LayoutConstants.nowDisplayingBarPaddingHorizontal,
          bottom: LayoutConstants.nowDisplayingBarPaddingBottom,
        ),
        child: child,
      ),
    );
  }
}

class _NowPlayingStatusBar extends StatelessWidget {
  const _NowPlayingStatusBar({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return _NowPlayingCardContainer(
      child: SizedBox(
        height: LayoutConstants.nowDisplayingBarCollapsedHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.body(context).white,
          ),
        ),
      ),
    );
  }
}

class _NowPlayingSleepBar extends ConsumerWidget {
  const _NowPlayingSleepBar({
    required this.deviceName,
  });

  final String deviceName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _NowPlayingCardContainer(
      backgroundColor: PrimitivesTokens.colorsNowPlayingBarInactive,
      child: SizedBox(
        height: LayoutConstants.nowDisplayingBarCollapsedHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: TopLine(color: PrimitivesTokens.colorsGrey)),
            SizedBox(height: LayoutConstants.space2),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sleeping',
                      style: AppTypography.body(context).grey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SleepModeIndicator(
                    isSleeping: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

