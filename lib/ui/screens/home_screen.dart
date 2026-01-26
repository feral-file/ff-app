import 'package:app/app/providers/bootstrap_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home screen - main entry point of the app.
class HomeScreen extends ConsumerStatefulWidget {
  /// Creates a HomeScreen.
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger bootstrap on first load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(bootstrapProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapStatus = ref.watch(bootstrapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feral File'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Feral File',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            // Bootstrap status indicator
            _BootstrapStatusWidget(status: bootstrapStatus),
            const SizedBox(height: 32),
            _NavigationButton(
              label: 'Channels',
              icon: Icons.rss_feed,
              onPressed: () => context.go(Routes.channels),
            ),
            const SizedBox(height: 16),
            _NavigationButton(
              label: 'Playlists',
              icon: Icons.playlist_play,
              onPressed: () => context.go(Routes.playlists),
            ),
            const SizedBox(height: 16),
            _NavigationButton(
              label: 'Works',
              icon: Icons.image,
              onPressed: () => context.go(Routes.works),
            ),
          ],
        ),
      ),
    );
  }
}

class _BootstrapStatusWidget extends StatelessWidget {
  const _BootstrapStatusWidget({required this.status});

  final BootstrapStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status.state) {
      case BootstrapState.idle:
        return const SizedBox.shrink();
      case BootstrapState.loading:
        return Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              status.message ?? 'Loading...',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        );
      case BootstrapState.success:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                status.message ?? 'Ready',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case BootstrapState.error:
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  status.message ?? 'Error',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(200, 48),
      ),
    );
  }
}
