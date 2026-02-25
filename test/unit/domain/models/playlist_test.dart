import 'package:app/domain/models/playlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Playlist', () {
    test('creates playlist with required fields', () {
      const playlist = Playlist(
        id: 'pl_123',
        name: 'Test Playlist',
        type: PlaylistType.dp1,
      );

      expect(playlist.id, equals('pl_123'));
      expect(playlist.name, equals('Test Playlist'));
      expect(playlist.description, isNull);
      expect(playlist.channelId, isNull);
      expect(playlist.playlistRole, isNull);
      expect(playlist.playlistSource, equals(PlaylistSource.personal));
    });

    test('creates curated playlist with role', () {
      const playlist = Playlist(
        id: 'pl_456',
        name: 'Exhibition Playlist',
        type: PlaylistType.dp1,
        description: 'A curated exhibition',
        channelId: 'ch_789',
        playlistRole: PlaylistRole.exhibition,
        playlistSource: PlaylistSource.curated,
      );

      expect(playlist.id, equals('pl_456'));
      expect(playlist.name, equals('Exhibition Playlist'));
      expect(playlist.playlistRole, equals(PlaylistRole.exhibition));
      expect(playlist.playlistSource, equals(PlaylistSource.curated));
    });

    test('copyWith creates new instance with updated values', () {
      const original = Playlist(
        id: 'pl_123',
        name: 'Test Playlist',
        type: PlaylistType.dp1,
      );

      final updated = original.copyWith(
        name: 'Updated Playlist',
        playlistSource: PlaylistSource.followed,
      );

      expect(updated.id, equals('pl_123'));
      expect(updated.name, equals('Updated Playlist'));
      expect(updated.playlistSource, equals(PlaylistSource.followed));

      // Original is unchanged
      expect(original.name, equals('Test Playlist'));
      expect(original.playlistSource, equals(PlaylistSource.personal));
    });
  });
}
