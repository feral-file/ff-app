import 'package:app/domain/models/models.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/graphql/indexer_client.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/personal_tokens_sync_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAppStateService implements AppStateService {
  @override
  Stream<AddressIndexingProcessStatus?> watchAddressIndexingStatus(
    String address,
  ) =>
      Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingIndexerService extends IndexerService {
  _RecordingIndexerService()
    : super(client: IndexerClient(endpoint: 'https://example.invalid'));

  final List<String> requestedAddresses = <String>[];

  @override
  Future<List<AssetToken>> fetchTokensByAddresses({
    required List<String> addresses,
    int? limit = 500,
    int? offset = 0,
  }) async {
    requestedAddresses.addAll(addresses);
    return <AssetToken>[];
  }
}

void main() {
  test('sync uses lowercased 0x address format for indexer fetch', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final databaseService = DatabaseService(database);
    const playlistOwner = '0X99FC8AD516FBCC9BA3123D56E63A35D05AA9EFB8';

    await databaseService.ingestPlaylist(
      const Playlist(
        id: 'addr:eth:0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8',
        name: 'Personal',
        type: PlaylistType.addressBased,
        channelId: 'my_collection',
        ownerAddress: playlistOwner,
        ownerChain: 'eth',
      ),
    );

    final indexer = _RecordingIndexerService();
    final service = PersonalTokensSyncService(
      indexerService: indexer,
      databaseService: databaseService,
      appStateService: _FakeAppStateService(),
    );

    await service.syncAddresses(addresses: const <String>[playlistOwner]);

    expect(
      indexer.requestedAddresses,
      equals(const <String>['0x99fc8ad516fbcc9ba3123d56e63a35d05aa9efb8']),
    );
  });
}
