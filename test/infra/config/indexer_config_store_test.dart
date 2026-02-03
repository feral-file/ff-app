import 'dart:io';

import 'package:app/infra/config/indexer_config_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../test_helpers/fake_path_provider.dart';

void main() {
  late Directory tempDir;
  late IndexerConfigStore store;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('indexer_config_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
    store = IndexerConfigStore(
      documentsDirFactory: () async => tempDir,
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('IndexerConfigStore', () {
    test('stores and retrieves anchors (normalizes address)', () async {
      await store.setAnchor('0xabc', 42);
      expect(await store.getAnchor('0xABC'), equals(42));
      expect(await store.getAnchor('0xabc'), equals(42));
    });

    test('stores and retrieves workflowId (normalizes address)', () async {
      await store.setIndexingWorkflowId(address: '0xabc', workflowId: 'wf1');
      expect(await store.getIndexingWorkflowId('0xABC'), equals('wf1'));
    });

    test('stores and retrieves last fetch token time', () async {
      final t = DateTime(2026, 2, 3, 12, 0).toUtc();
      await store.setLastFetchTokenTime('0xabc', t);
      expect(await store.getLastFetchTokenTime('0xABC'), equals(t));
    });

    test('persists data across store instances', () async {
      await store.setAnchor('0xabc', 42);
      await store.setIndexingWorkflowId(address: '0xabc', workflowId: 'wf1');
      final t = DateTime(2026, 2, 3, 12, 0).toUtc();
      await store.setLastFetchTokenTime('0xabc', t);

      final store2 = IndexerConfigStore(
        documentsDirFactory: () async => tempDir,
      );

      expect(await store2.getAnchor('0xABC'), equals(42));
      expect(await store2.getIndexingWorkflowId('0xABC'), equals('wf1'));
      expect(await store2.getLastFetchTokenTime('0xABC'), equals(t));
    });

    test('handles corrupted file gracefully', () async {
      final file = await store.resolveFile();
      file.writeAsStringSync('not json');

      expect(await store.getAnchor('0xABC'), isNull);
      expect(await store.getIndexingWorkflowId('0xABC'), isNull);
      expect(await store.getLastFetchTokenTime('0xABC'), isNull);
    });
  });
}

