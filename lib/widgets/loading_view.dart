import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:gif_view/gif_view.dart';

/// Loading view widget.
/// Uses GIF indicator (loading_white.gif) per Feral File design; no CircularProgressIndicator.
class LoadingView extends StatelessWidget {
  /// Creates a LoadingView.
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: LoadingWidget(
        backgroundColor: AppColor.auGreyBackground,
      ),
    );
  }
}

/// Loading widget with customizable appearance.
/// Uses GifView (loading_white.gif) for main loading states, matching old repo pattern.
class LoadingWidget extends StatelessWidget {
  /// Creates a LoadingWidget.
  const LoadingWidget({
    this.backgroundColor,
    this.width,
    this.height,
    this.frameRate,
    this.showText = true,
    this.text,
    this.invertColors = false,
    super.key,
  });

  /// Background color.
  final Color? backgroundColor;

  /// Optional width (default matches design: 52).
  final int? width;

  /// Optional height.
  final int? height;

  /// Optional frame rate for GIF (default 12).
  final int? frameRate;

  /// Whether to show loading text.
  final bool showText;

  /// Optional custom loading text.
  final String? text;

  /// Whether to invert GIF colors (e.g. for light backgrounds).
  final bool invertColors;

  /// Default GIF size matching old repo (52).
  static const double _loadingGifSize = 52;

  /// Minimum height needed for the default content (GIF + spacing + text).
  /// Used to avoid overflow when parent has tight height (e.g. carousel row 65px).
  static const double _minContentHeight = 66;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      width: width?.toDouble(),
      height: height?.toDouble(),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              GifView.asset(
                'assets/images/loading_white.gif',
                width: width?.toDouble() ?? _loadingGifSize,
                height: height?.toDouble(),
                frameRate: frameRate ?? 12,
                invertColors: invertColors,
              ),
              if (showText) ...[
                SizedBox(height: LayoutConstants.space3),
                Text(
                  text ?? 'Loading...',
                  style: AppTypography.bodySmall(context).white,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
