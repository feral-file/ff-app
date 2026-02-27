import 'dart:io';

import 'package:app/infra/logging/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await AppLogger.dispose();
  });

  test('initialize creates a log file in system temp', () async {
    await AppLogger.initialize();

    final logFile = AppLogger.currentLogFile;
    expect(logFile, isNotNull);
    expect(logFile!.existsSync(), isTrue);
    expect(logFile.path, startsWith(Directory.systemTemp.path));
    expect(logFile.path, endsWith('app.log'));
  });
}
