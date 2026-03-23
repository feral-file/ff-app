import 'package:app/domain/models/ff1/loop_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoopMode', () {
    group('wireValue', () {
      test('playlist returns "playlist"', () {
        expect(LoopMode.playlist.wireValue, 'playlist');
      });

      test('one returns "one"', () {
        expect(LoopMode.one.wireValue, 'one');
      });
    });

    group('fromString', () {
      test('parses "playlist"', () {
        expect(LoopMode.fromString('playlist'), LoopMode.playlist);
      });

      test('parses "one"', () {
        expect(LoopMode.fromString('one'), LoopMode.one);
      });

      test('throws on unknown value including removed "none"', () {
        expect(() => LoopMode.fromString('none'), throwsArgumentError);
        expect(() => LoopMode.fromString('unknown'), throwsArgumentError);
      });
    });

    group('next', () {
      test('playlist cycles to one', () {
        expect(LoopMode.playlist.next, LoopMode.one);
      });

      test('one cycles back to playlist', () {
        expect(LoopMode.one.next, LoopMode.playlist);
      });

      test('full cycle returns to start', () {
        expect(LoopMode.playlist.next.next, LoopMode.playlist);
      });
    });
  });
}
