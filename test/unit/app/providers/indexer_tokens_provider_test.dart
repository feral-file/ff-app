import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestAppStateService implements AppStateService {
  final Set<String> tracked = <String>{};

  @override
  Future<void> trackPersonalAddress(String address) async {
    tracked.add(address.toUpperCase());
  }

  @override
  Future<List<String>> getTrackedPersonalAddresses() async {
    return tracked.toList(growable: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePersonalTokensSyncService extends PersonalTokensSyncService {
  _FakePersonalTokensSyncService()
    : super(
        indexerService: IndexerService(
          client: IndexerClient(endpoint: 'https://example.invalid'),
        ),
        databaseService: DatabaseService(
          AppDatabase.forTesting(NativeDatabase.memory()),
        ),
        appStateService: _TestAppStateService(),
      );

  List<String>? lastSynced;
  Exception? syncError;

  @override
  Future<void> syncAddresses({required List<String> addresses}) async {
    lastSynced = List<String>.from(addresses);
    if (syncError != null) {
      throw syncError!;
    }
  }
}

Future<void> _seedAddressPlaylist(AppDatabase database, String address) async {
  final nowUs = DateTime.now().microsecondsSinceEpoch;
  await database.customStatement(
    '''
    INSERT INTO playlists (
      id, channel_id, type, base_url, dp_version, slug, title,
      created_at_us, updated_at_us, signatures_json, defaults_json,
      dynamic_queries_json, owner_address, owner_chain, sort_mode, item_count
    ) VALUES (?, NULL, 1, NULL, NULL, NULL, ?, ?, ?, '[]', NULL, NULL, ?, NULL, 1, 0)
    ''',
    <Object>[
      'pl_$address',
      'Address $address',
      nowUs,
      nowUs,
      address.toUpperCase(),
    ],
  );
}

void main() {
  test('TokensSyncState copyWith updates fields', () {
    const initial = TokensSyncState();
    final next = initial.copyWith(
      syncingAddresses: {'0xabc'},
      errorMessage: 'failed',
    );
    expect(next.syncingAddresses, {'0xabc'});
    expect(next.errorMessage, 'failed');
  });

  test('tokensSyncCoordinatorProvider builds', () {
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final state = container.read(tokensSyncCoordinatorProvider);
    expect(state.syncingAddresses, isEmpty);
    expect(state.errorMessage, isNull);
  });

  test('tokens sync coordinator can stop and drain for reset', () async {
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
    await notifier.stopAndDrainForReset();
    final state = container.read(tokensSyncCoordinatorProvider);
    expect(state.syncingAddresses, isEmpty);
  });

  test('tokens sync coordinator rebuilds safely after invalidation', () {
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    // Build once.
    expect(
      () => container.read(tokensSyncCoordinatorProvider.notifier),
      returnsNormally,
    );

    // Force rebuild and ensure no LateInitializationError is thrown.
    container.invalidate(tokensSyncCoordinatorProvider);
    expect(
      () => container.read(tokensSyncCoordinatorProvider.notifier),
      returnsNormally,
    );
  });

  test('tokens sync resumes after reset invalidation', () async {
    final fake = _FakePersonalTokensSyncService();

    final container = ProviderContainer.test(
      overrides: [
        appStateServiceProvider.overrideWithValue(_TestAppStateService()),
        personalTokensSyncServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
    await notifier.stopAndDrainForReset();

    container.invalidate(tokensSyncCoordinatorProvider);
    final rebuilt = container.read(tokensSyncCoordinatorProvider.notifier);

    await rebuilt.syncAddresses(const <String>['einstein-rosen.eth']);
    expect(fake.lastSynced, equals(<String>['einstein-rosen.eth']));
  });

  test('syncAddresses delegates to PersonalTokensSyncService', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final fake = _FakePersonalTokensSyncService();

    final container = ProviderContainer.test(
      overrides: [
        appStateServiceProvider.overrideWithValue(_TestAppStateService()),
        databaseServiceProvider.overrideWithValue(DatabaseService(database)),
        personalTokensSyncServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await _seedAddressPlaylist(database, 'einstein-rosen.eth');

    final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
    await notifier.syncAddresses(const <String>['einstein-rosen.eth']);

    expect(fake.lastSynced, equals(<String>['einstein-rosen.eth']));
  });

  test('syncAddresses stores errors from PersonalTokensSyncService', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final fake = _FakePersonalTokensSyncService()
      ..syncError = Exception('sync failed');

    final container = ProviderContainer.test(
      overrides: [
        appStateServiceProvider.overrideWithValue(_TestAppStateService()),
        databaseServiceProvider.overrideWithValue(DatabaseService(database)),
        personalTokensSyncServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    await _seedAddressPlaylist(database, 'einstein-rosen.eth');

    final notifier = container.read(tokensSyncCoordinatorProvider.notifier);
    await expectLater(
      notifier.syncAddresses(const <String>['einstein-rosen.eth']),
      throwsA(isA<Exception>()),
    );

    final state = container.read(tokensSyncCoordinatorProvider);
    expect(state.errorMessage, contains('sync failed'));
  });
}
