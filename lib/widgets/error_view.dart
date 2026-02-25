import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';

/// Error view widget with retry option
class ErrorView extends StatelessWidget {
  /// Creates an ErrorView.
  const ErrorView({
    required this.error,
    this.onRetry,
    super.key,
  });

  /// Error message to display.
  final String error;

  /// Optional retry callback.
  final void Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: LayoutConstants.pageHorizontalDefault,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error,
              style: AppTypography.bodySmall(context).white,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: LayoutConstants.space4),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: AppTypography.bodySmall(context).white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
