import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Loading view widget
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

/// Loading widget with customizable appearance
class LoadingWidget extends StatelessWidget {
  /// Creates a LoadingWidget.
  const LoadingWidget({
    this.backgroundColor,
    this.width,
    this.height,
    this.frameRate,
    this.showText = true,
    this.text,
    super.key,
  });

  /// Background color.
  final Color? backgroundColor;
  
  /// Optional width.
  final int? width;
  
  /// Optional height.
  final int? height;
  
  /// Optional frame rate.
  final int? frameRate;
  
  /// Whether to show loading text.
  final bool showText;
  
  /// Optional custom loading text.
  final String? text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      width: width?.toDouble(),
      height: height?.toDouble(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColor.white,
          ),
          if (showText) ...[
            const SizedBox(height: 16),
            Text(
              text ?? 'Loading...',
              style: const TextStyle(
                color: AppColor.white,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
