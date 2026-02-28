import 'package:app/app/feed/feed_manager.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/feral_file_dp1_feed_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopAppStateService implements AppStateService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test('init registers the default Feral File feed service', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final dbService = DatabaseService(db);
    final appStateService = _NoopAppStateService();
    final manager = FeralFileFeedManager(
      databaseService: dbService,
      appStateService: appStateService,
      defaultDp1FeedUrl: 'https://feeds.feralfile.com',
      defaultDp1FeedApiKey: 'test-key',
    );

    await manager.init();

    final service = manager.getFeedServiceByUrl('https://feeds.feralfile.com');
    expect(service, isA<FeralFileDP1FeedService>());
    expect(manager.feedServices.length, 1);

    await manager.init();
    expect(manager.feedServices.length, 1);
  });
}
