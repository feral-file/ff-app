import 'package:flutter/material.dart';

/// Work detail screen.
/// Shows details for a specific work (artwork).
class WorkDetailScreen extends StatelessWidget {
  /// Creates a WorkDetailScreen.
  const WorkDetailScreen({
    required this.workId,
    super.key,
  });

  /// The work ID to display.
  final String workId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Work $workId'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image, size: 64),
            const SizedBox(height: 16),
            Text(
              'Work Details',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'ID: $workId',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
