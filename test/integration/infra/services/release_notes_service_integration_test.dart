import 'dart:io';

import 'package:app/infra/services/release_notes_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test(
    'loads release notes from configured RELEASE_NOTES_MARKDOWN_URL and parses markdown',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      server.listen((request) async {
        if (request.uri.path == '/docs/changelog.md') {
          request.response
            ..statusCode = HttpStatus.ok
            ..write('''
## February 24, 2026
### FF OS
- Improved FF1 control stability
''');
        } else {
          request.response.statusCode = HttpStatus.notFound;
        }
        await request.response.close();
      });

      final tempDir = await Directory.systemTemp.createTemp(
        'ff_app_release_notes_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final envFile = File('${tempDir.path}/.env');
      await envFile.writeAsString(
        'RELEASE_NOTES_MARKDOWN_URL=http://${server.address.address}:${server.port}\n',
      );
      await dotenv.load(fileName: envFile.path);

      final service = ReleaseNotesService(
        httpClient: http.Client(),
      );

      final notes = await service.getReleaseNotes();
      expect(notes, hasLength(1));
      expect(notes.first.date, 'February 24, 2026');
      expect(notes.first.ffOsTitle, 'FF OS');
    },
  );
}
