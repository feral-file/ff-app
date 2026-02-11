import 'dart:io';

import 'package:app/infra/config/feed_config_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../test_helpers/fake_path_provider.dart';

void main() {
  late Directory tempDir;
  late FeedConfigStore store;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('feed_config_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);

    store = FeedConfigStore(
      documentsDirFactory: () async => tempDir,
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('FeedConfigStore', () {
    group('lastRefreshTime', () {
      test('returns epoch time for unknown baseUrl', () async {
        final time = await store.getLastRefreshTime('https://example.com');
        expect(time, equals(DateTime(1970)));
      });

      test('stores and retrieves lastRefreshTime per baseUrl', () async {
        final baseUrl1 = 'https://feed1.example';
        final baseUrl2 = 'https://feed2.example';
        final time1 = DateTime(2024, 1, 1, 12, 0);
        final time2 = DateTime(2024, 2, 1, 13, 0);

        await store.setLastRefreshTime(baseUrl1, time1);
        await store.setLastRefreshTime(baseUrl2, time2);

        final retrieved1 = await store.getLastRefreshTime(baseUrl1);
        final retrieved2 = await store.getLastRefreshTime(baseUrl2);

        expect(retrieved1, equals(time1));
        expect(retrieved2, equals(time2));
      });

      test('updates existing lastRefreshTime', () async {
        final baseUrl = 'https://feed.example';
        final time1 = DateTime(2024, 1, 1);
        final time2 = DateTime(2024, 2, 1);

        await store.setLastRefreshTime(baseUrl, time1);
        final retrieved1 = await store.getLastRefreshTime(baseUrl);
        expect(retrieved1, equals(time1));

        await store.setLastRefreshTime(baseUrl, time2);
        final retrieved2 = await store.getLastRefreshTime(baseUrl);
        expect(retrieved2, equals(time2));
      });
    });

    group('cacheDuration', () {
      test('returns default duration (1 day) when not set', () async {
        final duration = await store.getCacheDuration();
        expect(duration, equals(const Duration(days: 1)));
      });

      test('stores and retrieves custom cache duration', () async {
        const customDuration = Duration(hours: 12);

        await store.setCacheDuration(customDuration);
        final retrieved = await store.getCacheDuration();

        expect(retrieved, equals(customDuration));
      });
    });

    group('lastFeedUpdatedAt', () {
      test('returns default date (2023-01-01) when not set', () async {
        final time = await store.getLastFeedUpdatedAt();
        expect(time, equals(DateTime(2023)));
      });

      test('stores and retrieves lastFeedUpdatedAt', () async {
        final customTime = DateTime(2024, 6, 15, 10, 30);

        await store.setLastFeedUpdatedAt(customTime);
        final retrieved = await store.getLastFeedUpdatedAt();

        expect(retrieved, equals(customTime));
      });
    });

    group('sync stages', () {
      test('stage defaults to not completed', () async {
        expect(await store.isBareItemsLoaded(), isFalse);
        expect(await store.isTokensEnriched(), isFalse);
      });

      test('can mark stages complete', () async {
        final bareAt = DateTime(2025, 1, 1, 10, 0);
        final enrichedAt = DateTime(2025, 1, 1, 11, 0);

        await store.markBareItemsLoaded(at: bareAt);
        await store.markTokensEnriched(at: enrichedAt);

        expect(await store.isBareItemsLoaded(), isTrue);
        expect(await store.isTokensEnriched(), isTrue);
      });

      test('clearSyncStages resets both markers', () async {
        await store.markBareItemsLoaded();
        await store.markTokensEnriched();

        await store.clearSyncStages();

        expect(await store.isBareItemsLoaded(), isFalse);
        expect(await store.isTokensEnriched(), isFalse);
      });
    });

    group('address indexing states', () {
      test('stores and retrieves per-address indexing state', () async {
        final address = 'tz1abc123456789012345678901234567890123';
        final now = DateTime(2026, 2, 11, 11, 0).toUtc();

        await store.setAddressIndexingStatus(
          address: address,
          status: AddressIndexingProcessStatus(
            state: AddressIndexingProcessState.syncingTokens,
            updatedAt: now,
          ),
        );

        final status = await store.getAddressIndexingStatus(address);
        expect(status, isNotNull);
        expect(status?.state, AddressIndexingProcessState.syncingTokens);
        expect(status?.updatedAt, now);
      });

      test('clearAddressIndexingStatus removes state', () async {
        final address = '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8';
        await store.setAddressIndexingStatus(
          address: address,
          status: AddressIndexingProcessStatus(
            state: AddressIndexingProcessState.waitingForIndexStatus,
            updatedAt: DateTime.now().toUtc(),
            errorMessage: 'temporary',
          ),
        );

        expect(await store.getAddressIndexingStatus(address), isNotNull);
        await store.clearAddressIndexingStatus(address);
        expect(await store.getAddressIndexingStatus(address), isNull);
      });
    });

    group('file persistence', () {
      test('persists data across store instances', () async {
        final baseUrl = 'https://feed.example';
        final time = DateTime(2024, 1, 1);
        const duration = Duration(hours: 6);
        final lastUpdated = DateTime(2024, 2, 1);

        await store.setLastRefreshTime(baseUrl, time);
        await store.setCacheDuration(duration);
        await store.setLastFeedUpdatedAt(lastUpdated);

        // Create new store instance
        final store2 = FeedConfigStore(
          documentsDirFactory: () async => tempDir,
        );

        final retrievedTime = await store2.getLastRefreshTime(baseUrl);
        final retrievedDuration = await store2.getCacheDuration();
        final retrievedLastUpdated = await store2.getLastFeedUpdatedAt();

        expect(retrievedTime, equals(time));
        expect(retrievedDuration, equals(duration));
        expect(retrievedLastUpdated, equals(lastUpdated));
      });

      test('persists sync stage markers across store instances', () async {
        await store.markBareItemsLoaded();
        await store.markTokensEnriched();

        final store2 = FeedConfigStore(
          documentsDirFactory: () async => tempDir,
        );

        expect(await store2.isBareItemsLoaded(), isTrue);
        expect(await store2.isTokensEnriched(), isTrue);
      });

      test('handles missing file gracefully', () async {
        final time = await store.getLastRefreshTime('https://example.com');
        expect(time, equals(DateTime(1970)));
      });

      test('handles corrupted file gracefully', () async {
        final file = await store.resolveFile();
        file.writeAsStringSync('invalid json');

        final time = await store.getLastRefreshTime('https://example.com');
        expect(time, equals(DateTime(1970)));
      });
    });
  });
}
