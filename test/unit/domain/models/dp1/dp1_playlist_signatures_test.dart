import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/dp1/dp1_playlist_signature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dp1PlaylistSignaturesFromWire', () {
    test('maps legacy singular signature when signatures missing', () {
      final r = dp1PlaylistSignaturesFromWire({'signature': 'a'});
      expect(r.legacy, 'a');
      expect(r.structured, isEmpty);
    });

    test('prefers non-empty signatures list over legacy signature', () {
      final r = dp1PlaylistSignaturesFromWire({
        'signature': 'legacy',
        'signatures': ['a', 'b'],
      });
      expect(r.legacy, isNull);
      expect(r.structured.map((s) => s.sig), ['a', 'b']);
    });

    test('uses legacy signature when signatures is empty list', () {
      final r = dp1PlaylistSignaturesFromWire({
        'signature': 'legacy',
        'signatures': <dynamic>[],
      });
      expect(r.legacy, 'legacy');
      expect(r.structured, isEmpty);
    });

    test('returns empty when neither field provides values', () {
      final r = dp1PlaylistSignaturesFromWire({});
      expect(r.legacy, isNull);
      expect(r.structured, isEmpty);
      final r2 = dp1PlaylistSignaturesFromWire({'signature': ''});
      expect(r2.legacy, isNull);
      expect(r2.structured, isEmpty);
    });
  });

  group('DP1Playlist JSON', () {
    test('fromJson reads signatures array of strings as sig-only entries', () {
      final p = DP1Playlist.fromJson({
        'dpVersion': '1.0.0',
        'id': 'pl',
        'slug': 's',
        'title': 't',
        'created': '2025-01-01T00:00:00.000Z',
        'items': <dynamic>[],
        'signatures': ['x', 'y'],
      });
      expect(p.signatures.map((s) => s.sig), ['x', 'y']);
    });

    test('fromJson maps legacy signature string to legacySignature', () {
      final p = DP1Playlist.fromJson({
        'dpVersion': '1.0.0',
        'id': 'pl',
        'slug': 's',
        'title': 't',
        'created': '2025-01-01T00:00:00.000Z',
        'items': <dynamic>[],
        'signature': 'only-legacy',
      });
      expect(p.legacySignature, 'only-legacy');
      expect(p.signatures, isEmpty);
    });

    test('toJson emits structured signatures and omits empty legacy', () {
      final p = DP1Playlist(
        dpVersion: '1.0.0',
        id: 'pl',
        slug: 's',
        title: 't',
        created: DateTime.parse('2025-01-01T00:00:00.000Z'),
        items: const [],
        signatures: const [DP1PlaylistSignature(sig: 'a')],
      );
      final map = p.toJson();
      expect(map.containsKey('signature'), isFalse);
      expect(map['signatures'], [
        {'sig': 'a'},
      ]);
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
      expect(r.items.single.legacySignature, 'wire');
      expect(r.items.single.signatures, isEmpty);
    });
  });
}
