import 'package:app/app/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Channels list screen.
/// Shows all available channels (feeds) in the app.
class ChannelsScreen extends StatelessWidget {
  /// Creates a ChannelsScreen.
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
      ),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          final channelId = 'ch_${index + 1}';
          return ListTile(
            leading: const Icon(Icons.rss_feed),
            title: Text('Channel $channelId'),
            subtitle: const Text('Tap to view details'),
            onTap: () => context.go('${Routes.channels}/$channelId'),
          );
        },
      ),
    );
  }
}
