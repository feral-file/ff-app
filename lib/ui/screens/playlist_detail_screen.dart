import 'package:flutter/material.dart';

/// Playlist detail screen.
/// Shows details and works for a specific playlist.
/// Note: Exhibition/Season/Program are playlist roles (UI chrome),
/// not separate domain objects.
class PlaylistDetailScreen extends StatelessWidget {
  /// Creates a PlaylistDetailScreen.
  const PlaylistDetailScreen({
    required this.playlistId,
    super.key,
  });

  /// The playlist ID to display.
  final String playlistId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Playlist $playlistId'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.playlist_play, size: 64),
            const SizedBox(height: 16),
            Text(
              'Playlist Details',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'ID: $playlistId',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
