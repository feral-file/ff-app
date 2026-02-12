import 'package:app/domain/models/channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Channel', () {
    test('creates channel with required fields', () {
      const channel = Channel(
        id: 'ch_123',
        name: 'Test Channel',
        type: ChannelType.dp1,
      );

      expect(channel.id, equals('ch_123'));
      expect(channel.name, equals('Test Channel'));
      expect(channel.description, isNull);
      expect(channel.isPinned, isFalse);
    });

    test('creates channel with all fields', () {
      const channel = Channel(
        id: 'ch_456',
        name: 'Complete Channel',
        type: ChannelType.localVirtual,
        description: 'A test channel',
        isPinned: true,
      );

      expect(channel.id, equals('ch_456'));
      expect(channel.name, equals('Complete Channel'));
      expect(channel.type, equals(ChannelType.localVirtual));
      expect(channel.description, equals('A test channel'));
      expect(channel.isPinned, isTrue);
    });

    test('copyWith creates new instance with updated values', () {
      const original = Channel(
        id: 'ch_123',
        name: 'Test Channel',
        type: ChannelType.dp1,
      );

      final updated = original.copyWith(
        name: 'Updated Channel',
        isPinned: true,
      );

      expect(updated.id, equals('ch_123'));
      expect(updated.name, equals('Updated Channel'));
      expect(updated.isPinned, isTrue);

      // Original is unchanged
      expect(original.name, equals('Test Channel'));
      expect(original.isPinned, isFalse);
    });
  });
}
