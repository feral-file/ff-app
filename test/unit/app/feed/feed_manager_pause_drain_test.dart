import 'dart:async';

import 'package:app/app/feed/feed_manager.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/base_dp1_feed_service_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopAppStateService implements AppStateService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _BlockingFeedService extends BaseDP1FeedServiceImpl {
  _BlockingFeedService({
    required this.reloadStarted,
    required this.reloadGate,
    required super.databaseService,
    required super.appStateService,
  }) : super(baseUrl: 'https://example.org', apiKey: '');

  final Completer<void> reloadStarted;
  final Completer<void> reloadGate;
  bool pausedCalled = false;

  @override
  void setPaused(bool paused) {
    pausedCalled = paused;
    super.setPaused(paused);
  }

  @override
  Future<void> reloadCacheIfNeeded({bool force = false}) async {
    if (!reloadStarted.isCompleted) {
      reloadStarted.complete();
    }
    await reloadGate.future;
  }
}

void main() {
  test(
    'pauseAndDrainWork waits for in-flight reload before returning',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final dbService = DatabaseService(db);
      final appState = _NoopAppStateService();
      final manager = FeedManager(
        databaseService: dbService,
        appStateService: appState,
      );

      final reloadStarted = Completer<void>();
      final reloadGate = Completer<void>();
      final feedService = _BlockingFeedService(
        reloadStarted: reloadStarted,
        reloadGate: reloadGate,
        databaseService: dbService,
        appStateService: appState,
      );

      manager.addFeedService(feedService);

      unawaited(manager.reloadAllCache(force: true));
      await reloadStarted.future.timeout(const Duration(seconds: 2));

      var drained = false;
      final drainFuture = manager.pauseAndDrainWork().then((_) {
        drained = true;
      });

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(drained, isFalse);
      expect(feedService.pausedCalled, isTrue);

      reloadGate.complete();
      await drainFuture.timeout(const Duration(seconds: 2));

      expect(drained, isTrue);
    },
  );
}
