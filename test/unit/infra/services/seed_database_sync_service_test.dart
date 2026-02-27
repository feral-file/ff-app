import 'package:app/infra/services/seed_database_service.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSeedDatabaseService extends SeedDatabaseService {
  _FakeSeedDatabaseService({
    required this.hasLocal,
    required this.remoteEtag,
    this.throwOnHead = false,
  });

  bool hasLocal;
  String remoteEtag;
  bool throwOnHead;

  int downloadCalls = 0;
  int replaceCalls = 0;

  @override
  Future<bool> hasLocalDatabase() async => hasLocal;

  @override
  Future<String> headRemoteEtag() async {
    if (throwOnHead) {
      throw DioException(
        requestOptions: RequestOptions(path: 'https://example.invalid/seed.sqlite'),
        message: 'offline',
      );
    }
    return remoteEtag;
  }

  @override
  Future<String> downloadToTemporaryFile({
    void Function(double progress)? onProgress,
    int? maxBytes,
  }) async {
    downloadCalls += 1;
    onProgress?.call(1);
    return '/tmp/seed.sqlite.tmp';
  }

  @override
  Future<void> replaceDatabaseFromTemporaryFile(String tempPath) async {
    replaceCalls += 1;
  }
}

void main() {
  group('SeedDatabaseSyncService', () {
    test('downloads and replaces when ETag changed', () async {
      final fakeSeedService = _FakeSeedDatabaseService(
        hasLocal: true,
        remoteEtag: 'remote-v2',
      );
      var localEtag = 'local-v1';
      final events = <String>[];

      final service = SeedDatabaseSyncService(
        seedDatabaseService: fakeSeedService,
        loadLocalEtag: () => localEtag,
        saveLocalEtag: (etag) => localEtag = etag,
      );

      final changed = await service.syncIfNeeded(
        beforeReplace: () async => events.add('before'),
        afterReplace: () async => events.add('after'),
      );

      expect(changed, isTrue);
      expect(fakeSeedService.downloadCalls, 1);
      expect(fakeSeedService.replaceCalls, 1);
      expect(events, ['before', 'after']);
      expect(localEtag, 'remote-v2');
    });

    test('skips download when ETag unchanged and DB exists', () async {
      final fakeSeedService = _FakeSeedDatabaseService(
        hasLocal: true,
        remoteEtag: 'same-etag',
      );
      var localEtag = 'same-etag';
      final events = <String>[];

      final service = SeedDatabaseSyncService(
        seedDatabaseService: fakeSeedService,
        loadLocalEtag: () => localEtag,
        saveLocalEtag: (etag) => localEtag = etag,
      );

      final changed = await service.syncIfNeeded(
        beforeReplace: () async => events.add('before'),
        afterReplace: () async => events.add('after'),
      );

      expect(changed, isFalse);
      expect(fakeSeedService.downloadCalls, 0);
      expect(fakeSeedService.replaceCalls, 0);
      expect(events, isEmpty);
      expect(localEtag, 'same-etag');
    });

    test('fails silently on network error when requested', () async {
      final fakeSeedService = _FakeSeedDatabaseService(
        hasLocal: true,
        remoteEtag: '',
        throwOnHead: true,
      );
      var localEtag = 'local-v1';
      final events = <String>[];

      final service = SeedDatabaseSyncService(
        seedDatabaseService: fakeSeedService,
        loadLocalEtag: () => localEtag,
        saveLocalEtag: (etag) => localEtag = etag,
      );

      final changed = await service.syncIfNeeded(
        beforeReplace: () async => events.add('before'),
        afterReplace: () async => events.add('after'),
        failSilently: true,
      );

      expect(changed, isFalse);
      expect(fakeSeedService.downloadCalls, 0);
      expect(fakeSeedService.replaceCalls, 0);
      expect(events, isEmpty);
      expect(localEtag, 'local-v1');
    });
  });
}
