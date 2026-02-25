import 'package:app/design/app_typography.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Visual style variant for a [GlobalToastPayload].
enum ToastStyle {
  /// Ongoing operation: shows a spinner; transitions to a "Done ✓" state for
  /// 500 ms when the toast is dismissed.
  loading,

  /// Informational message: shows an info icon.
  info,
}

/// Payload for global toast overlays.
class GlobalToastPayload {
  /// Creates a [GlobalToastPayload].
  const GlobalToastPayload({
    required this.message,
    this.style = ToastStyle.loading,
  });

  /// Toast text content.
  final String message;

  /// Visual style variant controlling the leading icon and dismiss behaviour.
  final ToastStyle style;
}

/// Router-managed global toast overlay.
///
/// For [ToastStyle.loading], the widget intercepts the pop request, switches
/// to a "Done ✓" state for 500 ms, then completes the pop.
/// For [ToastStyle.info], the toast pops immediately without the done step.
class GlobalToastOverlayScreen extends StatefulWidget {
  /// Creates a [GlobalToastOverlayScreen].
  const GlobalToastOverlayScreen({
    required this.payload,
    super.key,
  });

  /// Payload carrying toast text and style.
  final GlobalToastPayload payload;

  @override
  State<GlobalToastOverlayScreen> createState() =>
      _GlobalToastOverlayScreenState();
}

class _GlobalToastOverlayScreenState extends State<GlobalToastOverlayScreen> {
  bool _isDone = false;

  bool get _isLoading => widget.payload.style == ToastStyle.loading;

  Future<void> _handlePopInvoked(bool didPop, void result) async {
    if (didPop || _isDone || !_isLoading) return;
    setState(() => _isDone = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      // Hold the pop for loading toasts until the "Done" animation completes.
      canPop: !_isLoading || _isDone,
      onPopInvokedWithResult: _handlePopInvoked,
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: AppTypography.body(context).copyWith(color: AppColor.white),
          child: IgnorePointer(
            child: SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColor.primaryBlack,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _buildToastContent(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToastContent(BuildContext context) {
    if (_isLoading && _isDone) {
      return const _ToastRow(
        key: ValueKey('done'),
        icon: Icon(Icons.check, color: AppColor.white, size: 16),
        message: 'Done',
      );
    }

    final icon = switch (widget.payload.style) {
      ToastStyle.loading => const SizedBox.square(
          key: ValueKey('loading'),
          dimension: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColor.white,
          ),
        ),
      ToastStyle.info => const Icon(
          key: ValueKey('info'),
          Icons.info_outline,
          color: AppColor.white,
          size: 16,
        ),
    };

    return _ToastRow(
      key: ValueKey(widget.payload.style),
      icon: icon,
      message: widget.payload.message,
    );
  }
}

class _ToastRow extends StatelessWidget {
  const _ToastRow({
    required this.icon,
    required this.message,
    super.key,
  });

  final Widget icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Text(
          message,
          style: AppTypography.body(context).copyWith(color: AppColor.white),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
