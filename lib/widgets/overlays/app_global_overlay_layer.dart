import 'dart:async';

import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/now_displaying_bar/now_displaying_bar.dart';
import 'package:app/widgets/now_displaying_bar/two_stop_draggable_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _toastAnimationDuration = Duration(milliseconds: 220);

/// App-level overlay layer rendered above the navigation/content stack.
class AppGlobalOverlayLayer extends ConsumerWidget {
  /// Creates an [AppGlobalOverlayLayer].
  const AppGlobalOverlayLayer({
    required this.router,
    super.key,
  });

  /// App router used by the global now displaying overlay.
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlays = ref.watch(appOverlayProvider);
    final defaultToastTextStyle =
        AppTypography.body(
          context,
        ).copyWith(
          color: AppColor.white,
          decoration: TextDecoration.none,
        );

    return Stack(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: isNowDisplayingBarExpanded,
          builder: (context, expanded, _) {
            if (!expanded) {
              return const SizedBox.shrink();
            }

            return Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: NowDisplayingSheetController.collapse,
                child: const ColoredBox(
                  color: Colors.transparent,
                ),
              ),
            );
          },
        ),
        const _BottomFadeGradient(),
        NowDisplayingBarOverlay(router: router),
        Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: defaultToastTextStyle,
            child: Stack(
              children: [
                for (final overlay in overlays)
                  if (overlay is AppToastOverlayItem)
                    _ToastOverlayPresenter(
                      key: ValueKey<String>(overlay.id),
                      overlay: overlay,
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ToastOverlayPresenter extends ConsumerStatefulWidget {
  const _ToastOverlayPresenter({
    required this.overlay,
    super.key,
  });

  final AppToastOverlayItem overlay;

  @override
  ConsumerState<_ToastOverlayPresenter> createState() =>
      _ToastOverlayPresenterState();
}

class _ToastOverlayPresenterState
    extends ConsumerState<_ToastOverlayPresenter> {
  Timer? _autoDismissTimer;
  var _isVisible = false;

  @override
  void initState() {
    super.initState();
    _scheduleAutoDismiss();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isVisible = true;
      });
    });
  }

  @override
  void didUpdateWidget(_ToastOverlayPresenter oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.overlay.id != widget.overlay.id ||
        oldWidget.overlay.autoDismissAfter != widget.overlay.autoDismissAfter) {
      _scheduleAutoDismiss();
    }

    if (!oldWidget.overlay.isDismissing &&
        widget.overlay.isDismissing &&
        !_isVisible) {
      ref.read(appOverlayProvider.notifier).removeOverlay(widget.overlay.id);
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTapThrough =
        widget.overlay.interactionMode == OverlayInteractionMode.tapThrough;

    return Positioned.fill(
      child: Stack(
        children: [
          if (!isTapThrough)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: IgnorePointer(
                  ignoring: isTapThrough,
                  child: AnimatedOpacity(
                    opacity: _targetOpacity,
                    duration: _toastAnimationDuration,
                    onEnd: _handleOpacityAnimationEnd,
                    child: _ToastCard(overlay: widget.overlay),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _targetOpacity {
    if (!_isVisible || widget.overlay.isDismissing) {
      return 0;
    }
    return 1;
  }

  void _scheduleAutoDismiss() {
    _autoDismissTimer?.cancel();
    final autoDismissAfter = widget.overlay.autoDismissAfter;
    if (autoDismissAfter == null) {
      return;
    }

    _autoDismissTimer = Timer(autoDismissAfter, () {
      if (!mounted) {
        return;
      }
      _dismiss();
    });
  }

  void _dismiss() {
    ref.read(appOverlayProvider.notifier).dismissOverlay(widget.overlay.id);
  }

  void _handleOpacityAnimationEnd() {
    if (!widget.overlay.isDismissing || _targetOpacity != 0) {
      return;
    }
    ref.read(appOverlayProvider.notifier).removeOverlay(widget.overlay.id);
  }
}

class _BottomFadeGradient extends ConsumerWidget {
  const _BottomFadeGradient();

  static const _fadeHeightBarVisible = 120.0;
  static const _fadeHeightBarHidden = 48.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final barVisible = ref.watch(
      nowDisplayingVisibilityProvider.select((s) => s.shouldShow),
    );
    final fadeHeight = barVisible
        ? _fadeHeightBarVisible
        : _fadeHeightBarHidden;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final totalHeight = fadeHeight + bottomInset;
    final opaqueStop = fadeHeight * 0.37 / totalHeight;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: totalHeight,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, opaqueStop, 1.0],
              colors: const [
                Color(0x002E2E2E),
                Color(0xFF2E2E2E),
                Color(0xFF2E2E2E),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.overlay,
  });

  final AppToastOverlayItem overlay;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColor.primaryBlack,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: -1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                overlay.message,
                style:
                    AppTypography.body(
                      context,
                    ).copyWith(
                      color: AppColor.white,
                      decoration: TextDecoration.none,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return switch (overlay.iconPreset) {
      ToastOverlayIconPreset.loading => const SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColor.white,
        ),
      ),
      ToastOverlayIconPreset.information => const Icon(
        Icons.info_outline,
        color: AppColor.white,
        size: 16,
      ),
    };
  }
}
