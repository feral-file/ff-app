import 'package:flutter/material.dart';

/// Channel detail screen.
/// Shows details and content for a specific channel.
class ChannelDetailScreen extends StatelessWidget {
  /// Creates a ChannelDetailScreen.
  const ChannelDetailScreen({
    required this.channelId,
    super.key,
  });

  /// The channel ID to display.
  final String channelId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Channel $channelId'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rss_feed, size: 64),
            const SizedBox(height: 16),
            Text(
              'Channel Details',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'ID: $channelId',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
