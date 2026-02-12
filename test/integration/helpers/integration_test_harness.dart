import 'dart:io';

import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;

/// Shared integration-test context with real on-disk SQLite resources.
class IntegrationTestContext {
  IntegrationTestContext({
    required this.tempDir,
    required this.databaseFile,
    required this.database,
    required this.databaseService,
    required this.provisionedEnvFile,
  });

  final Directory tempDir;
  final File databaseFile;
  final AppDatabase database;
  final DatabaseService databaseService;
  final File provisionedEnvFile;

  Future<void> dispose() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  }
}

/// Provisions a concrete .env file for integration tests and loads it.
Future<File> provisionIntegrationEnvFile() async {
  final sourceEnv = File('.env');
  if (!sourceEnv.existsSync()) {
    throw StateError(
      'Missing .env at project root. '
      'Integration tests require a real .env file.',
    );
  }

  final tempDir = await Directory.systemTemp.createTemp('ff_app_env_');
  final provisionedEnvFile = File(p.join(tempDir.path, '.env'));
  await provisionedEnvFile.writeAsString(await sourceEnv.readAsString());

  await dotenv.load(fileName: provisionedEnvFile.path);

  return provisionedEnvFile;
}

/// Creates an integration test context backed by a real sqlite file.
Future<IntegrationTestContext> createIntegrationTestContext() async {
  final provisionedEnvFile = await provisionIntegrationEnvFile();
  final tempDir = await Directory.systemTemp.createTemp('ff_app_sqlite_');
  final databaseFile = File(p.join(tempDir.path, 'ff_app_integration.sqlite'));

  final executor = NativeDatabase.createInBackground(databaseFile);
  final database = AppDatabase.forTesting(executor);
  final databaseService = DatabaseService(database);

  return IntegrationTestContext(
    tempDir: tempDir,
    databaseFile: databaseFile,
    database: database,
    databaseService: databaseService,
    provisionedEnvFile: provisionedEnvFile,
  );
}
