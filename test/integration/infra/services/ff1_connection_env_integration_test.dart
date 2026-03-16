import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/integration_test_harness.dart';

void main() {
  late File provisionedEnvFile;

  setUpAll(() async {
    provisionedEnvFile = await provisionIntegrationEnvFile();
  });

  tearDownAll(() async {
    final dir = provisionedEnvFile.parent;
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  test('loads FF1 test device connection identifiers from shared env', () {
    final ff1TestDeviceId =
        dotenv.env['FF1_TEST_DEVICE_ID']?.trim() ?? '';
    final ff1TestTopicId =
        dotenv.env['FF1_TEST_TOPIC_ID']?.trim() ?? '';

    // This connection check is only enforced when FF1 test credentials are
    // configured in .env for integration runs.
    if (ff1TestDeviceId.isEmpty && ff1TestTopicId.isEmpty) {
      return;
    }

    expect(ff1TestDeviceId, isNotEmpty);
    expect(ff1TestTopicId, isNotEmpty);
  });
}
