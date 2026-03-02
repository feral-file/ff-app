import 'package:app/app/utils/html/prepare_truncated_html.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prepareTruncatedHtmlForRender', () {
    test('returns input when HTML has no dangling tag fragment', () {
      const html = '<em>Hello</em> world';
      expect(prepareTruncatedHtmlForRender(html), html);
    });

    test('trims trailing dangling fragment and appends ellipsis', () {
      const html = 'Hello <em>world</e';
      expect(prepareTruncatedHtmlForRender(html), 'Hello <em>world…');
    });

    test('can trim without ellipsis', () {
      const html = 'Hello <em>world</e';
      expect(
        prepareTruncatedHtmlForRender(html, addEllipsisOnTrim: false),
        'Hello <em>world',
      );
    });

    test('returns empty when only dangling fragment remains', () {
      const html = '<em';
      expect(prepareTruncatedHtmlForRender(html), '');
    });
  });

  group('prepareHtmlForRender', () {
    test('converts newlines into <br/> when no paragraph tags exist', () {
      const html = 'Title\n\nDescription';
      expect(
        prepareHtmlForRender(html),
        'Title<br/><br/>Description',
      );
    });

    test('keeps existing <p> structure (no newline conversion)', () {
      const html = '<p>One</p>\n<p>Two</p>';
      expect(prepareHtmlForRender(html), html);
    });

    test('keeps existing <br> tags (no newline conversion)', () {
      const html = 'One<br/>Two\nThree';
      expect(prepareHtmlForRender(html), html);
    });

    test('still trims dangling tag fragments before rendering', () {
      const html = 'Hello <em>world</e';
      expect(
        prepareHtmlForRender(html),
        'Hello <em>world…',
      );
    });
  });
}
