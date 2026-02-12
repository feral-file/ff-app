import 'dart:async';

import 'package:app/app/providers/addresses_provider.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('addressesProvider maps address playlists to wallet addresses', () async {
    // Unit test: verifies stream mapping from playlist rows to wallet-address view model.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);
    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => dbService),
      ],
    );
    addTearDown(container.dispose);

    final completer = Completer<List<WalletAddress>>();
    final sub = container.listen<AsyncValue<List<WalletAddress>>>(
      addressesProvider,
      (_, next) {
        next.whenData((value) {
          if (value.isNotEmpty && !completer.isCompleted) {
            completer.complete(value);
          }
        });
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await dbService.ingestPlaylist(
      const Playlist(
        id: 'pl_addr_1',
        name: 'Address A',
        type: PlaylistType.addressBased,
        ownerAddress: '0xabc',
        ownerChain: 'ETH',
      ),
    );

    final addresses = await completer.future;
    expect(addresses.length, 1);
    expect(addresses.first.address, '0xabc');
    expect(addresses.first.name, 'Address A');
  });
}
