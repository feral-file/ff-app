import 'dart:io';

Map<String, String> loadRootEnvValues() {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    return const <String, String>{};
  }

  final values = <String, String>{};
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }

    final separatorIndex = trimmed.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }

    final key = trimmed.substring(0, separatorIndex).trim();
    final value = trimmed
        .substring(separatorIndex + 1)
        .trim()
        .replaceAll(RegExp(r'^"|"$'), '')
        .replaceAll(RegExp(r"^'|'$"), '');
    values[key] = value;
  }

  return values;
}

bool hasValidS3SeedConfig(Map<String, String> env) {
  final bucketUrl = env['S3_BUCKET'] ?? '';
  final accessKey = env['S3_ACCESS_KEY_ID'] ?? '';
  final secretKey = env['S3_SECRET_ACCESS_KEY'] ?? '';
  final objectKey = env['S3_SEED_DATABASE_OBJECT_KEY'] ?? '';
  final region = env['S3_REGION'] ?? '';

  final uri = Uri.tryParse(bucketUrl);
  final hasBucketPath =
      uri != null &&
      uri.hasScheme &&
      uri.host.isNotEmpty &&
      uri.pathSegments.where((segment) => segment.isNotEmpty).isNotEmpty;

  return hasBucketPath &&
      accessKey.trim().isNotEmpty &&
      secretKey.trim().isNotEmpty &&
      objectKey.trim().isNotEmpty &&
      region.trim().isNotEmpty;
}

bool hasValidFf1RelayerConfig(Map<String, String> env) {
  final relayerUrl = env['FF1_RELAYER_URL'] ?? '';
  final relayerApiKey = env['FF1_RELAYER_API_KEY'] ?? '';
  return relayerUrl.trim().isNotEmpty && relayerApiKey.trim().isNotEmpty;
}

String resolveIntegrationTopicId(Map<String, String> env) {
  final configured = env['FF1_TEST_TOPIC_ID'] ?? '';
  return configured.trim();
}
