import 'dart:async';

import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _toastAnimationDuration = Duration(milliseconds: 220);

/// App-level overlay layer rendered above the navigation/content stack.
class AppGlobalOverlayLayer extends ConsumerWidget {
  /// Creates an [AppGlobalOverlayLayer].
  const AppGlobalOverlayLayer({super.key});

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

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: defaultToastTextStyle,
        child: IgnorePointer(
          ignoring: overlays.isEmpty,
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
            color: Colors.black.withOpacity(0.32),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
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
