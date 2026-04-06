import 'package:app/domain/models/ff1/loop_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoopMode', () {
    group('wireValue', () {
      test('none returns "none"', () {
        expect(LoopMode.none.wireValue, 'none');
      });

      test('playlist returns "playlist"', () {
        expect(LoopMode.playlist.wireValue, 'playlist');
      });

      test('one returns "one"', () {
        expect(LoopMode.one.wireValue, 'one');
      });
    });

    group('tryParse', () {
      test('parses known wire strings', () {
        expect(LoopMode.tryParse('none'), LoopMode.none);
        expect(LoopMode.tryParse('playlist'), LoopMode.playlist);
        expect(LoopMode.tryParse('one'), LoopMode.one);
      });

      test('returns null for null, empty, non-string, or unknown', () {
        expect(LoopMode.tryParse(null), isNull);
        expect(LoopMode.tryParse(''), isNull);
        expect(LoopMode.tryParse(1), isNull);
        expect(LoopMode.tryParse('unknown'), isNull);
      });
    });

    group('fromString', () {
      test('parses "none"', () {
        expect(LoopMode.fromString('none'), LoopMode.none);
      });

      test('parses "playlist"', () {
        expect(LoopMode.fromString('playlist'), LoopMode.playlist);
      });

      test('parses "one"', () {
        expect(LoopMode.fromString('one'), LoopMode.one);
      });

      test('throws on unknown value', () {
        expect(() => LoopMode.fromString('unknown'), throwsArgumentError);
      });
    });

    group('next', () {
      test('none cycles to playlist', () {
        expect(LoopMode.none.next, LoopMode.playlist);
      });

      test('playlist cycles to one', () {
        expect(LoopMode.playlist.next, LoopMode.one);
      });

      test('one cycles to none', () {
        expect(LoopMode.one.next, LoopMode.none);
      });

      test('full cycle returns to start', () {
        expect(
          LoopMode.none.next.next.next,
          LoopMode.none,
        );
      });
    });
  });
}
