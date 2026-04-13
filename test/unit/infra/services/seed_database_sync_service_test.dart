import 'package:app/infra/services/seed_database_artifact_validator.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:app/infra/services/seed_database_sync_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSeedDatabaseService extends SeedDatabaseService {
  _FakeSeedDatabaseService({
    required this.hasLocal,
    required this.remoteEtag,
    this.throwOnHead = false,
    this.throwOnReplace = false,
    this.throwOnValidate = false,
  });

  bool hasLocal;
  String remoteEtag;
  bool throwOnHead;
  bool throwOnReplace;
  bool throwOnValidate;

  int downloadCalls = 0;
  int validateCalls = 0;
  int replaceCalls = 0;

  @override
  Future<bool> hasLocalDatabase() async => hasLocal;

  @override
  Future<String> headRemoteEtag() async {
    if (throwOnHead) {
      throw DioException(
        requestOptions: RequestOptions(
          path: 'https://example.invalid/seed.sqlite',
        ),
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
  SeedDatabaseArtifactMetadata validateSeedArtifact(String path) {
    validateCalls += 1;
    if (throwOnValidate) {
      throw const SeedArtifactValidationException(
        reasonCode: 'magic_mismatch',
        message: 'Invalid seed artifact',
      );
    }
    return const SeedDatabaseArtifactMetadata(fileSize: 1024, userVersion: 3);
  }

  @override
  Future<void> replaceDatabaseFromTemporaryFile(String tempPath) async {
    replaceCalls += 1;
    if (throwOnReplace) {
      throw Exception('Simulated replace failure');
    }
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

      final changed = await service.sync(
        beforeReplace: () async => events.add('before'),
        afterReplace: () async => events.add('after'),
      );

      expect(changed, isTrue);
      expect(fakeSeedService.downloadCalls, 1);
      expect(fakeSeedService.validateCalls, 1);
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

      final changed = await service.sync(
        beforeReplace: () async => events.add('before'),
        afterReplace: () async => events.add('after'),
      );

      expect(changed, isFalse);
      expect(fakeSeedService.downloadCalls, 0);
      expect(fakeSeedService.validateCalls, 0);
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

      final changed = await service.sync(
        beforeReplace: () async => events.add('before'),
        afterReplace: () async => events.add('after'),
        failSilently: true,
      );

      expect(changed, isFalse);
      expect(fakeSeedService.downloadCalls, 0);
      expect(fakeSeedService.validateCalls, 0);
      expect(fakeSeedService.replaceCalls, 0);
      expect(events, isEmpty);
      expect(localEtag, 'local-v1');
    });

    test(
      'forceReplace always downloads and replaces, skipping ETag check',
      () async {
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

        final changed = await service.sync(
          beforeReplace: () async => events.add('before'),
          afterReplace: () async => events.add('after'),
          forceReplace: true,
        );

        expect(changed, isTrue);
        expect(fakeSeedService.downloadCalls, 1);
        expect(fakeSeedService.validateCalls, 1);
        expect(fakeSeedService.replaceCalls, 1);
        expect(events, ['before', 'after']);
        expect(localEtag, 'same-etag'); // ETag saved after replace (from HEAD)
      },
    );

    test(
      'when replace fails after beforeReplace, sync returns false and '
      'afterReplace is not called; old DB remains '
      '(project_spec fallback invariant)',
      () async {
        final fakeSeedService = _FakeSeedDatabaseService(
          hasLocal: true,
          remoteEtag: 'remote-v2',
          throwOnReplace: true,
        );
        var localEtag = 'local-v1';
        final events = <String>[];

        final service = SeedDatabaseSyncService(
          seedDatabaseService: fakeSeedService,
          loadLocalEtag: () => localEtag,
          saveLocalEtag: (etag) => localEtag = etag,
        );

        final changed = await service.sync(
          beforeReplace: () async => events.add('before'),
          afterReplace: () async => events.add('after'),
          failSilently: true,
        );

        expect(changed, isFalse);
        expect(fakeSeedService.validateCalls, 1);
        expect(fakeSeedService.replaceCalls, 1);
        expect(events, ['before']);
        expect(localEtag, 'local-v1');
      },
    );

    test(
      'when isSessionActive flips false before beforeReplace, bails early '
      'without running teardown',
      () async {
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

        final changed = await service.sync(
          beforeReplace: () async => events.add('before'),
          afterReplace: () async => events.add('after'),
          isSessionActive: () => false,
        );

        expect(changed, isFalse);
        expect(fakeSeedService.validateCalls, 1);
        expect(fakeSeedService.replaceCalls, 0);
        expect(events, isEmpty);
      },
    );

    test(
      'when isSessionActive flips false after beforeReplace, completes replace '
      '+ afterReplace to preserve reconnect path (Codex P1)',
      () async {
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

        var callCount = 0;
        final changed = await service.sync(
          beforeReplace: () async {
            events.add('before');
          },
          afterReplace: () async => events.add('after'),
          isSessionActive: () {
            callCount++;
            return callCount <= 1;
          },
        );

        expect(changed, isTrue);
        expect(fakeSeedService.validateCalls, 1);
        expect(fakeSeedService.replaceCalls, 1);
        expect(events, ['before', 'after']);
        expect(localEtag, 'remote-v2');
      },
    );

    test(
      'validation failure returns false before beforeReplace or replace',
      () async {
        final fakeSeedService = _FakeSeedDatabaseService(
          hasLocal: false,
          remoteEtag: 'remote-v2',
          throwOnValidate: true,
        );
        var localEtag = '';
        final events = <String>[];

        final service = SeedDatabaseSyncService(
          seedDatabaseService: fakeSeedService,
          loadLocalEtag: () => localEtag,
          saveLocalEtag: (etag) => localEtag = etag,
        );

        final changed = await service.sync(
          beforeReplace: () async => events.add('before'),
          afterReplace: () async => events.add('after'),
          failSilently: true,
        );

        expect(changed, isFalse);
        expect(fakeSeedService.downloadCalls, 1);
        expect(fakeSeedService.validateCalls, 1);
        expect(fakeSeedService.replaceCalls, 0);
        expect(events, isEmpty);
        expect(localEtag, isEmpty);
      },
    );
  });
}
