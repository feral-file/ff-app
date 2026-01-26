import 'package:app/app/providers/channels_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Channels list screen.
/// Shows all available channels (feeds) in the app.
class ChannelsScreen extends ConsumerStatefulWidget {
  /// Creates a ChannelsScreen.
  const ChannelsScreen({super.key});

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends ConsumerState<ChannelsScreen> {
  @override
  void initState() {
    super.initState();
    // Load channels on first mount
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(channelsProvider.notifier).loadChannels();
    });
  }

  @override
  Widget build(BuildContext context) {
    final channelsState = ref.watch(channelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await ref.read(channelsProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: _buildBody(channelsState),
    );
  }

  Widget _buildBody(ChannelsState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red.shade700, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error: ${state.error}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await ref.read(channelsProvider.notifier).refresh();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.channels.isEmpty) {
      return const Center(
        child: Text('No channels available'),
      );
    }

    return ListView.builder(
      itemCount: state.channels.length,
      itemBuilder: (context, index) {
        final channel = state.channels[index];
        return ListTile(
          leading: const Icon(Icons.rss_feed),
          title: Text(channel.name),
          subtitle: Text(
            channel.description ?? 'Tap to view details',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: channel.isPinned
              ? const Icon(Icons.push_pin, size: 16)
              : null,
          onTap: () => context.go('${Routes.channels}/${channel.id}'),
        );
      },
    );
  }
}
