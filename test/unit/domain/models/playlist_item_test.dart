import 'package:app/domain/extensions/playlist_item_ext.dart';
import 'package:app/domain/models/dp1/dp1_manifest.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlaylistItem', () {
    test('creates playlist item with required fields', () {
      const item = PlaylistItem(
        id: 'item_123',
        kind: PlaylistItemKind.indexerToken,
        title: 'Test Item',
      );

      expect(item.id, equals('item_123'));
      expect(item.kind, equals(PlaylistItemKind.indexerToken));
      expect(item.title, equals('Test Item'));
      expect(item.artistName, '');
      expect(item.thumbnailUrl, isNull);
      expect(item.source, isNull);
    });

    test('creates playlist item with all fields', () {
      const item = PlaylistItem(
        id: 'item_456',
        kind: PlaylistItemKind.dp1Item,
        title: 'Complete Item',
        artists: [DP1Artist(name: 'Test Artist', id: 'artist_123')],
        thumbnailUrl: 'https://example.com/thumb.jpg',
        source: 'https://example.com/media.mp4',
      );

      expect(item.id, equals('item_456'));
      expect(item.kind, equals(PlaylistItemKind.dp1Item));
      expect(item.title, equals('Complete Item'));
      expect(item.artistName, equals('Test Artist'));
      expect(item.thumbnailUrl, equals('https://example.com/thumb.jpg'));
      expect(item.sourceUrl, equals('https://example.com/media.mp4'));
    });

    test('copyWith creates new instance with updated values', () {
      const original = PlaylistItem(
        id: 'item_123',
        kind: PlaylistItemKind.indexerToken,
        title: 'Test Item',
      );

      final updated = original.copyWith(
        title: 'Updated Item',
        artists: [const DP1Artist(name: 'New Artist', id: 'artist_456')],
      );

      expect(updated.id, equals('item_123'));
      expect(updated.title, equals('Updated Item'));
      expect(updated.artistName, equals('New Artist'));

      // Original is unchanged
      expect(original.title, equals('Test Item'));
      expect(original.artistName, equals(''));
    });

    test('toJson serializes correctly', () {
      const item = PlaylistItem(
        id: 'item_test',
        kind: PlaylistItemKind.indexerToken,
        title: 'Test Item',
        subtitle: 'Test Artist',
      );

      final json = item.toJson();

      expect(json['id'], equals('item_test'));
      expect(json['kind'], equals(1)); // indexerToken
      expect(json['title'], equals('Test Item'));
      expect(json['subtitle'], equals('Test Artist'));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'id': 'item_test',
        'kind': 1,
        'title': 'Test Item',
        'subtitle': 'Test Artist',
      };

      final item = PlaylistItem.fromJson(json);

      expect(item.id, equals('item_test'));
      expect(item.kind, equals(PlaylistItemKind.indexerToken));
      expect(item.title, equals('Test Item'));
      expect(item.subtitle, equals('Test Artist'));
    });
  });
}
