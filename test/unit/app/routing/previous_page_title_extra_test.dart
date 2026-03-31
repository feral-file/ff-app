import 'package:app/app/routing/previous_page_title_extra.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('previousPageTitleFromExtra', () {
    test('returns title for PreviousPageTitleExtra', () {
      expect(
        previousPageTitleFromExtra(const PreviousPageTitleExtra('Channels')),
        'Channels',
      );
    });

    test('returns null for other extra types', () {
      expect(previousPageTitleFromExtra(null), isNull);
      expect(previousPageTitleFromExtra('string'), isNull);
      expect(previousPageTitleFromExtra(42), isNull);
    });

    test('treats generic Index title as missing', () {
      expect(
        previousPageTitleFromExtra(const PreviousPageTitleExtra('Index')),
        isNull,
      );
    });

    test('trims surrounding whitespace from titles', () {
      expect(
        previousPageTitleFromExtra(const PreviousPageTitleExtra(' Playlists ')),
        'Playlists',
      );
    });
  });
}
