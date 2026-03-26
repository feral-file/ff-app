import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dp1PlaylistSignaturesFromWire', () {
    test('maps legacy singular signature when signatures missing', () {
      expect(
        dp1PlaylistSignaturesFromWire({'signature': 'a'}),
        ['a'],
      );
    });

    test('prefers non-empty signatures list over legacy signature', () {
      expect(
        dp1PlaylistSignaturesFromWire({
          'signature': 'legacy',
          'signatures': ['a', 'b'],
        }),
        ['a', 'b'],
      );
    });

    test('uses legacy signature when signatures is empty list', () {
      expect(
        dp1PlaylistSignaturesFromWire({
          'signature': 'legacy',
          'signatures': <dynamic>[],
        }),
        ['legacy'],
      );
    });

    test('returns empty list when neither field provides values', () {
      expect(dp1PlaylistSignaturesFromWire({}), isEmpty);
      expect(
        dp1PlaylistSignaturesFromWire({'signature': ''}),
        isEmpty,
      );
    });
  });

  group('DP1Playlist JSON', () {
    test('fromJson reads signatures array', () {
      final p = DP1Playlist.fromJson({
        'dpVersion': '1.0.0',
        'id': 'pl',
        'slug': 's',
        'title': 't',
        'created': '2025-01-01T00:00:00.000Z',
        'items': <dynamic>[],
        'signatures': ['x', 'y'],
      });
      expect(p.signatures, ['x', 'y']);
    });

    test('fromJson maps legacy signature string to signatures', () {
      final p = DP1Playlist.fromJson({
        'dpVersion': '1.0.0',
        'id': 'pl',
        'slug': 's',
        'title': 't',
        'created': '2025-01-01T00:00:00.000Z',
        'items': <dynamic>[],
        'signature': 'only-legacy',
      });
      expect(p.signatures, ['only-legacy']);
    });

    test('toJson emits signatures only', () {
      final p = DP1Playlist(
        dpVersion: '1.0.0',
        id: 'pl',
        slug: 's',
        title: 't',
        created: DateTime.parse('2025-01-01T00:00:00.000Z'),
        items: const [],
        signatures: const ['a'],
      );
      final map = p.toJson();
      expect(map.containsKey('signature'), isFalse);
      expect(map['signatures'], ['a']);
    });
  });

  group('DP1PlaylistResponse', () {
    test('normalizes playlist items with legacy signature field', () {
      final r = DP1PlaylistResponse.fromJson({
        'items': [
          {
            'dpVersion': '1.0.0',
            'id': 'pl',
            'slug': 's',
            'title': 't',
            'created': '2025-01-01T00:00:00.000Z',
            'items': <dynamic>[],
            'signature': 'wire',
          },
        ],
        'hasMore': false,
      });
      expect(r.items.single.signatures, ['wire']);
    });
  });
}
