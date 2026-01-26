import 'package:app/domain/models/work.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Work', () {
    test('creates work with required fields', () {
      const work = Work(
        id: 'wk_123',
        title: 'Test Work',
      );

      expect(work.id, equals('wk_123'));
      expect(work.title, equals('Test Work'));
      expect(work.artistName, isNull);
      expect(work.thumbnailUrl, isNull);
      expect(work.mediaUrl, isNull);
    });

    test('creates work with all fields', () {
      const work = Work(
        id: 'wk_456',
        title: 'Complete Work',
        artistName: 'Test Artist',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        mediaUrl: 'https://example.com/media.mp4',
      );

      expect(work.id, equals('wk_456'));
      expect(work.title, equals('Complete Work'));
      expect(work.artistName, equals('Test Artist'));
      expect(work.thumbnailUrl, equals('https://example.com/thumb.jpg'));
      expect(work.mediaUrl, equals('https://example.com/media.mp4'));
    });

    test('copyWith creates new instance with updated values', () {
      const original = Work(
        id: 'wk_123',
        title: 'Test Work',
      );

      final updated = original.copyWith(
        title: 'Updated Work',
        artistName: 'New Artist',
      );

      expect(updated.id, equals('wk_123'));
      expect(updated.title, equals('Updated Work'));
      expect(updated.artistName, equals('New Artist'));

      // Original is unchanged
      expect(original.title, equals('Test Work'));
      expect(original.artistName, isNull);
    });
  });
}
