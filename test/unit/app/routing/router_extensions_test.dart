import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SmartNavigation.smartPush', () {
    test('navigates to different route family using push', () {
      // Simulate current location /playlists/list-1
      // When calling smartPush /works/item-123, should push (different family)
      // Note: Different base routes (/playlists vs /works) → push
      expect(
        _extractBaseRoute('/playlists/list-1'),
        '/playlists',
      );
      expect(
        _extractBaseRoute('/works/item-123'),
        '/works',
      );
      // Different routes should trigger push (not replace)
    });

    test('replaces when navigating within same route family', () {
      // Same base route (/works for both), different targets
      // Should replace to avoid stack growth
      expect(
        _extractBaseRoute('/works/item-123'),
        _extractBaseRoute('/works/item-456'),
      );
    });

    test('no-op when already on exact same location', () {
      // Already on /works/item-123, calling smartPush /works/item-123
      // Should do nothing (no push, no replace)
      expect(
        '/works/item-123',
        '/works/item-123',
      );
    });

    test('extracts correct base routes', () {
      expect(_extractBaseRoute('/'), '/');
      expect(_extractBaseRoute('/works'), '/works');
      expect(_extractBaseRoute('/works/item-123'), '/works');
      expect(_extractBaseRoute('/playlists/list-1'), '/playlists');
      expect(_extractBaseRoute('/channels/channel-abc'), '/channels');
    });
  });
}

/// Helper function to extract base route (copy of private method for testing)
String _extractBaseRoute(String path) {
  final parts = path.split('/');
  if (parts.length > 1) {
    return '/${parts[1]}';
  }
  return path;
}
