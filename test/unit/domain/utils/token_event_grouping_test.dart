import 'package:app/domain/models/indexer/sync_collection.dart';
import 'package:app/domain/utils/token_event_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('groupTokenEvents', () {
    test('empty events returns empty sets', () {
      final result = groupTokenEvents(
        events: const [],
        address: '0xAAA',
      );
      expect(result.removalTokenIds, isEmpty);
      expect(result.updatedTokenIds, isEmpty);
    });

    test('released with owner_address match -> removal', () {
      final events = [
        TokenEvent(
          id: 1,
          tokenId: 100,
          eventType: 'released',
          ownerAddress: '0xaaa',
          occurredAt: DateTime.utc(2024),
        ),
      ];
      final result = groupTokenEvents(
        events: events,
        address: '0xAAA',
      );
      expect(result.removalTokenIds, {100});
      expect(result.updatedTokenIds, isEmpty);
    });

    test('acquired with owner_address match -> updated', () {
      final events = [
        TokenEvent(
          id: 1,
          tokenId: 100,
          eventType: 'acquired',
          ownerAddress: '0xaaa',
          occurredAt: DateTime.utc(2024),
        ),
      ];
      final result = groupTokenEvents(
        events: events,
        address: '0xAAA',
      );
      expect(result.removalTokenIds, isEmpty);
      expect(result.updatedTokenIds, {100});
    });

    test('A transfers to B, B back to A: last event acquired -> updated', () {
      final events = [
        TokenEvent(
          id: 1,
          tokenId: 100,
          eventType: 'released',
          ownerAddress: '0xaaa',
          occurredAt: DateTime.utc(2024),
        ),
        TokenEvent(
          id: 2,
          tokenId: 100,
          eventType: 'acquired',
          ownerAddress: '0xaaa',
          occurredAt: DateTime.utc(2024, 1, 2),
        ),
      ];
      final result = groupTokenEvents(
        events: events,
        address: '0xAAA',
      );
      expect(result.removalTokenIds, isEmpty);
      expect(result.updatedTokenIds, {100});
    });

    test('metadata_updated -> updated', () {
      final events = [
        TokenEvent(
          id: 1,
          tokenId: 100,
          eventType: 'metadata_updated',
          occurredAt: DateTime.utc(2024),
        ),
      ];
      final result = groupTokenEvents(
        events: events,
        address: '0xAAA',
      );
      expect(result.removalTokenIds, isEmpty);
      expect(result.updatedTokenIds, {100});
    });

    test('multiple tokens: mixed removal and updated', () {
      final events = [
        TokenEvent(
          id: 1,
          tokenId: 100,
          eventType: 'released',
          ownerAddress: '0xaaa',
          occurredAt: DateTime.utc(2024),
        ),
        TokenEvent(
          id: 2,
          tokenId: 200,
          eventType: 'acquired',
          ownerAddress: '0xaaa',
          occurredAt: DateTime.utc(2024),
        ),
        TokenEvent(
          id: 3,
          tokenId: 300,
          eventType: 'metadata_updated',
          occurredAt: DateTime.utc(2024),
        ),
      ];
      final result = groupTokenEvents(
        events: events,
        address: '0xAAA',
      );
      expect(result.removalTokenIds, {100});
      expect(result.updatedTokenIds, {200, 300});
    });

    test('viewability_changed with is_viewable: false -> removal', () {
      final events = [
        TokenEvent(
          id: 1,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024),
          metadata: {'is_viewable': true},
        ),
        TokenEvent(
          id: 2,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 2),
          metadata: {'is_viewable': false},
        ),
        TokenEvent(
          id: 3,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 3),
          metadata: {'is_viewable': true},
        ),
        TokenEvent(
          id: 4,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 4),
          metadata: {'is_viewable': false},
        ),
        TokenEvent(
          id: 5,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 5),
          metadata: {'is_viewable': false},
        ),
      ];
      final result = groupTokenEvents(
        events: events,
        address: '0xAAA',
      );
      expect(result.removalTokenIds, {100});
      expect(result.updatedTokenIds, isEmpty);
    });

    test('viewability_changed with is_viewable: true -> updated', () {
      final events = [
        TokenEvent(
          id: 1,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024),
          metadata: {'is_viewable': false},
        ),
        TokenEvent(
          id: 2,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 2),
          metadata: {'is_viewable': true},
        ),
        TokenEvent(
          id: 3,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 3),
          metadata: {'is_viewable': false},
        ),
        TokenEvent(
          id: 4,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 4),
          metadata: {'is_viewable': true},
        ),
        TokenEvent(
          id: 5,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 5),
          metadata: {'is_viewable': true},
        ),
      ];
      final result = groupTokenEvents(
        events: events,
        address: '0xAAA',
      );
      expect(result.removalTokenIds, isEmpty);
      expect(result.updatedTokenIds, {100});
    });

    test('viewability_changed with metadata null or missing is_viewable -> updated',
        () {
      final events = [
        TokenEvent(
          id: 1,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024),
          metadata: {'is_viewable': false},
        ),
        TokenEvent(
          id: 2,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 2),
        ),
        TokenEvent(
          id: 3,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 3),
          metadata: {'is_viewable': true},
        ),
        TokenEvent(
          id: 4,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 4),
        ),
        TokenEvent(
          id: 5,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 5),
        ),
      ];
      final result = groupTokenEvents(
        events: events,
        address: '0xAAA',
      );
      expect(result.removalTokenIds, isEmpty);
      expect(result.updatedTokenIds, {100});
    });

    test('viewability_changed is_viewable: false overrides prior acquired', () {
      final events = [
        TokenEvent(
          id: 1,
          tokenId: 100,
          eventType: 'acquired',
          ownerAddress: '0xaaa',
          occurredAt: DateTime.utc(2024),
        ),
        TokenEvent(
          id: 2,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 2),
          metadata: {'is_viewable': true},
        ),
        TokenEvent(
          id: 3,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 3),
          metadata: {'is_viewable': false},
        ),
        TokenEvent(
          id: 4,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 4),
          metadata: {'is_viewable': true},
        ),
        TokenEvent(
          id: 5,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 5),
          metadata: {'is_viewable': false},
        ),
        TokenEvent(
          id: 6,
          tokenId: 100,
          eventType: 'viewability_changed',
          occurredAt: DateTime.utc(2024, 1, 6),
          metadata: {'is_viewable': false},
        ),
      ];
      final result = groupTokenEvents(
        events: events,
        address: '0xAAA',
      );
      expect(result.removalTokenIds, {100});
      expect(result.updatedTokenIds, isEmpty);
    });
  });
}
