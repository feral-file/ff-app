import 'package:app/app/routing/previous_page_title_extra.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('previousPageTitleFromExtra', () {
    test('returns null for non PreviousPageTitleExtra payloads', () {
      expect(previousPageTitleFromExtra(null), isNull);
      expect(previousPageTitleFromExtra('Playlists'), isNull);
      expect(previousPageTitleFromExtra(123), isNull);
    });

    test('trims and returns the title', () {
      expect(
        previousPageTitleFromExtra(const PreviousPageTitleExtra(' Playlists ')),
        'Playlists',
      );
    });

    test('treats empty and "Index" as missing', () {
      expect(
        previousPageTitleFromExtra(const PreviousPageTitleExtra('')),
        isNull,
      );
      expect(
        previousPageTitleFromExtra(const PreviousPageTitleExtra('   ')),
        isNull,
      );
      expect(
        previousPageTitleFromExtra(const PreviousPageTitleExtra('Index')),
        isNull,
      );
      expect(
        previousPageTitleFromExtra(const PreviousPageTitleExtra(' Index ')),
        isNull,
      );
    });
  });

  group('previousPageTitleExtraFromTitle', () {
    test('returns null for missing/blank titles', () {
      expect(previousPageTitleExtraFromTitle(null), isNull);
      expect(previousPageTitleExtraFromTitle(''), isNull);
      expect(previousPageTitleExtraFromTitle('   '), isNull);
    });

    test('trims and wraps valid titles', () {
      expect(
        previousPageTitleExtraFromTitle(' Playlists ')?.title,
        'Playlists',
      );
    });

    test('treats "Index" as missing', () {
      expect(previousPageTitleExtraFromTitle('Index'), isNull);
      expect(previousPageTitleExtraFromTitle(' Index '), isNull);
    });
  });
}
