import 'package:app/infra/services/release_notes_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('parseReleaseNotesMarkdown', () {
    test('parses release entries and section titles', () {
      const markdown = '''
## February 20, 2026
### FF OS
- Device update
### Mobile App
- App update

## February 10, 2026
### Mobile
- Search improvements
''';

      final notes = parseReleaseNotesMarkdown(markdown);

      expect(notes, hasLength(2));
      expect(notes.first.date, 'February 20, 2026');
      expect(notes.first.ffOsTitle, 'FF OS');
      expect(notes.first.mobileAppTitle, 'Mobile App');
      expect(notes.first.content, contains('- Device update'));

      expect(notes.last.date, 'February 10, 2026');
      expect(notes.last.ffOsTitle, isNull);
      expect(notes.last.mobileAppTitle, 'Mobile');
    });

    test('parses sections when headers appear inline with separators', () {
      const markdown = '''
# Change logs
## Feb 24 2026
### FF OS 1.0.8
Fixes.
--- ## Feb 4 2026 ### Feral File Mobile App 1.0.9
Improvements.
''';

      final notes = parseReleaseNotesMarkdown(markdown);

      expect(notes, hasLength(2));
      expect(notes.first.date, 'Feb 24 2026');
      expect(notes.first.ffOsTitle, contains('FF OS'));
      expect(notes[1].date, 'Feb 4 2026');
      expect(notes[1].mobileAppTitle, contains('Mobile App'));
    });
  });

  group('ReleaseNotesService', () {
    test('fetches and parses markdown from pubdoc endpoint', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://pubdoc.feralfile.com/docs/changelog.md',
        );

        return http.Response('''
## February 24, 2026
### Mobile App
- Added release note screen
''', 200);
      });

      final service = ReleaseNotesService(
        httpClient: client,
        baseUri: Uri.parse('https://pubdoc.feralfile.com'),
      );

      final notes = await service.getReleaseNotes();

      expect(notes, hasLength(1));
      expect(notes.first.date, 'February 24, 2026');
      expect(notes.first.mobileAppTitle, 'Mobile App');
    });

    test('returns empty list on non-2xx response', () async {
      final client = MockClient((request) async => http.Response('nope', 404));
      final service = ReleaseNotesService(
        httpClient: client,
        baseUri: Uri.parse('https://pubdoc.feralfile.com'),
      );

      final notes = await service.getReleaseNotes();
      expect(notes, isEmpty);
    });

    test('keeps base path segments when building release-notes URI', () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://raw.githubusercontent.com/feral-file/docs/main/docs/changelog.md',
        );
        return http.Response('## February 24, 2026', 200);
      });

      final service = ReleaseNotesService(
        httpClient: client,
        baseUri: Uri.parse(
          'https://raw.githubusercontent.com/feral-file/docs/main',
        ),
      );

      final notes = await service.getReleaseNotes();
      expect(notes, hasLength(1));
      expect(notes.first.date, 'February 24, 2026');
    });

    test(
      'uses markdown URL directly when '
      'RELEASE_NOTES_MARKDOWN_URL points to .md',
      () async {
        final client = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://raw.githubusercontent.com/feral-file/docs/main/docs/changelog.md',
          );
          return http.Response('## February 24, 2026', 200);
        });

        final service = ReleaseNotesService(
          httpClient: client,
          baseUri: Uri.parse(
            'https://raw.githubusercontent.com/feral-file/docs/main/docs/changelog.md',
          ),
        );

        final notes = await service.getReleaseNotes();
        expect(notes, hasLength(1));
        expect(notes.first.date, 'February 24, 2026');
      },
    );
  });
}
