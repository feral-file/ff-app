import 'package:app/widgets/delayed_loading.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:flutter/material.dart';

/// Loading indicator shown while seed data is downloading.
class SeedSyncLoadingIndicator extends StatelessWidget {
  /// Creates a [SeedSyncLoadingIndicator].
  const SeedSyncLoadingIndicator({
    required this.progress,
    super.key,
  });

  /// Seed download progress in the 0.0 to 1.0 range.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final progressPercent = ((progress ?? 0) * 100).round();
    return Center(
      child: DelayedLoadingGate(
        isLoading: true,
        child: LoadingWidget(
          backgroundColor: Colors.transparent,
          text: 'Updating art library... $progressPercent%',
        ),
      ),
    );
  }
}
