import 'package:app/app/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Home screen - main entry point of the app.
class HomeScreen extends StatelessWidget {
  /// Creates a HomeScreen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
