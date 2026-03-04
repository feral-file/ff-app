import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/base_dp1_feed_service_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reloadCacheIfNeeded marks refresh metadata after successful reload',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final dbService = DatabaseService(database);
      final appStateService = _SpyAppStateService(
        lastRefresh: DateTime(2024),
        lastFeedUpdatedAt: DateTime(2024),
        cacheDuration: const Duration(minutes: 1),
      );
      final service = _TrackingFeedService(
        databaseService: dbService,
        appStateService: appStateService,
      );

      await service.reloadCacheIfNeeded();

      expect(service.reloadCalls, equals(1));
      expect(appStateService.setLastRefreshCalled, isTrue);
      expect(appStateService.setFeedBareIngestCalled, isTrue);
      expect(appStateService.setLastFeedUpdatedAtCalled, isTrue);
      expect(appStateService.lastStoredFeedCompleted, isTrue);
    },
  );

  test('reloadCacheIfNeeded skips refresh when cache is fresh', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final now = DateTime.now();
    final dbService = DatabaseService(database);
    final appStateService = _SpyAppStateService(
      lastRefresh: now,
      lastFeedUpdatedAt: now,
      cacheDuration: const Duration(days: 1),
    );
    final service = _TrackingFeedService(
      databaseService: dbService,
      appStateService: appStateService,
    );

    await service.reloadCacheIfNeeded();

    expect(service.reloadCalls, equals(0));
    expect(appStateService.setLastRefreshCalled, isFalse);
    expect(appStateService.setFeedBareIngestCalled, isFalse);
    expect(appStateService.setLastFeedUpdatedAtCalled, isFalse);
  });
}

class _TrackingFeedService extends BaseDP1FeedServiceImpl {
  _TrackingFeedService({
    required super.databaseService,
    required super.appStateService,
  }) : super(baseUrl: 'https://feeds.feralfile.com', apiKey: 'test-key');

  int reloadCalls = 0;

  @override
  Future<void> reloadCache() async {
    reloadCalls += 1;
  }
}

class _SpyAppStateService implements AppStateService {
  _SpyAppStateService({
    required this.lastRefresh,
    required this.lastFeedUpdatedAt,
    required this.cacheDuration,
  });

  final DateTime lastRefresh;
  final DateTime lastFeedUpdatedAt;
  final Duration cacheDuration;

  bool setLastRefreshCalled = false;
  bool setLastFeedUpdatedAtCalled = false;
  bool setFeedBareIngestCalled = false;
  bool? lastStoredFeedCompleted;

  bool hasSeen = false;

  @override
  Future<DateTime> getLastRefreshTime(String baseUrl) async => lastRefresh;

  @override
  Future<void> setLastRefreshTime(String baseUrl, DateTime time) async {
    setLastRefreshCalled = true;
  }

  @override
  Future<bool> hasFeedBareIngestCompleted(String baseUrl) async => false;

  @override
  Future<void> setFeedBareIngestCompleted({
    required String baseUrl,
    required bool completed,
    DateTime? completedAt,
  }) async {
    setFeedBareIngestCalled = true;
    lastStoredFeedCompleted = completed;
  }

  @override
  Future<void> deleteLastRefreshTime(String baseUrl) async {}

  @override
  Future<Duration> getCacheDuration() async => cacheDuration;

  @override
  Future<void> setCacheDuration(Duration duration) async {}

  @override
  Future<DateTime> getLastFeedUpdatedAt() async => lastFeedUpdatedAt;

  @override
  Future<void> setLastFeedUpdatedAt(DateTime time) async {
    setLastFeedUpdatedAtCalled = true;
  }

  @override
  Future<bool> hasSeenOnboarding() async => hasSeen;

  @override
  Future<void> setHasSeenOnboarding({required bool hasSeen}) async {}

  @override
  Future<bool> hasSeenPlayToFf1Tooltip() async => false;

  @override
  Future<void> setHasSeenPlayToFf1Tooltip({required bool hasSeen}) async {}

  @override
  Future<int?> getAddressAnchor(String address) async => null;

  @override
  Future<void> setAddressAnchor({
    required String address,
    required int anchor,
  }) async {}

  @override
  Future<void> clearAddressAnchor(String address) async {}

  @override
  Future<AddressIndexingProcessStatus?> getAddressIndexingStatus(
    String address,
  ) async => null;

  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) =>
      Stream.value(null);

  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {}

  @override
  Future<void> clearAddressState(String address) async {}

  @override
  Future<Map<String, AddressIndexingProcessStatus>>
  getAllAddressIndexingStatuses() async =>
      <String, AddressIndexingProcessStatus>{};

  @override
  Future<void> trackPersonalAddress(String address) async {}

  @override
  Future<List<String>> getTrackedPersonalAddresses() async => <String>[];

  @override
  void debugLogSummary() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
