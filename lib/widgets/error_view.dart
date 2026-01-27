import 'package:app/design/app_typography.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error,
              style: AppTypography.body(context).grey,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: Text(
                  'Retry',
                  style: AppTypography.body(context).white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
