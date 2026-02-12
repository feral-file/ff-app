import 'dart:io';

import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/objectbox.g.dart' show openStore;
import 'package:flutter_test/flutter_test.dart';
import 'package:objectbox/objectbox.dart';

void main() {
  late Directory tempDir;
  late Store objectBoxStore;
  late AppStateService store;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('app_state_test_');
    objectBoxStore = await openStore(directory: tempDir.path);
    store = AppStateService(
      appStateBox: objectBoxStore.box<AppStateEntity>(),
      appStateAddressBox: objectBoxStore.box<AppStateAddressEntity>(),
    );
  });

  tearDown(() async {
    objectBoxStore.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('stores onboarding and tooltip flags', () async {
    expect(await store.hasSeenOnboarding(), isFalse);
    expect(await store.hasSeenPlayToFf1Tooltip(), isFalse);

    await store.setHasSeenOnboarding(hasSeen: true);
    await store.setHasSeenPlayToFf1Tooltip(hasSeen: true);

    expect(await store.hasSeenOnboarding(), isTrue);
    expect(await store.hasSeenPlayToFf1Tooltip(), isTrue);
  });

  test('stores feed cache policy state', () async {
    final baseUrl = 'https://feed.example';
    final refreshAt = DateTime.utc(2026, 2, 10);
    final updatedAt = DateTime.utc(2026, 2, 12);

    await store.setCacheDuration(const Duration(hours: 6));
    await store.setLastFeedUpdatedAt(updatedAt);
    await store.setLastRefreshTime(baseUrl, refreshAt);

    expect(await store.getCacheDuration(), const Duration(hours: 6));
    expect(await store.getLastFeedUpdatedAt(), updatedAt);
    expect(await store.getLastRefreshTime(baseUrl), refreshAt);
  });

  test('stores per-address anchor + indexing status', () async {
    const address = '0xabc';
    final now = DateTime.utc(2026, 2, 12);

    await store.setAddressAnchor(address: address, anchor: 42);
    await store.setAddressIndexingStatus(
      address: address,
      status: AddressIndexingProcessStatus(
        state: AddressIndexingProcessState.syncingTokens,
        updatedAt: now,
      ),
    );

    expect(await store.getAddressAnchor(address), 42);
    final status = await store.getAddressIndexingStatus(address);
    expect(status?.state, AddressIndexingProcessState.syncingTokens);
    expect(status?.updatedAt, now);

    await store.clearAddressAnchor(address);
    await store.clearAddressIndexingStatus(address);

    expect(await store.getAddressAnchor(address), isNull);
    expect(await store.getAddressIndexingStatus(address), isNull);
  });
}
