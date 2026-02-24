import 'package:app/design/app_typography.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';

/// Payload for global toast overlays.
class GlobalToastPayload {
  /// Creates a [GlobalToastPayload].
  const GlobalToastPayload({
    required this.message,
  });

  /// Toast text content.
  final String message;
}

/// Router-managed global toast overlay.
class GlobalToastOverlayScreen extends StatelessWidget {
  /// Creates a [GlobalToastOverlayScreen].
  const GlobalToastOverlayScreen({
    required this.payload,
    super.key,
  });

  /// Payload carrying toast text.
  final GlobalToastPayload payload;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
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
                child: Text(
                  payload.message,
                  style: AppTypography.body(context).copyWith(
                    color: AppColor.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
