import 'dart:async';

import 'package:app/app/providers/channel_detail_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channelDetailsProvider combines channel and channel playlists', () async {
    // Unit test: verifies channel detail stream combines channel row and playlist rows.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final dbService = DatabaseService(db);
    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => dbService),
      ],
    );
    addTearDown(container.dispose);

    final completer = Completer<ChannelDetails>();
    final sub = container.listen<AsyncValue<ChannelDetails>>(
      channelDetailsProvider('ch_1'),
      (_, next) {
        next.whenData((value) {
          if (value.channel?.id == 'ch_1' && !completer.isCompleted) {
            completer.complete(value);
          }
        });
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await dbService.ingestChannel(
      const Channel(id: 'ch_1', name: 'Channel 1', type: ChannelType.dp1),
    );
    await dbService.ingestPlaylist(
      const Playlist(
        id: 'pl_1',
        name: 'Playlist 1',
        type: PlaylistType.dp1,
        channelId: 'ch_1',
      ),
    );

    final details = await completer.future;
    expect(details.channel?.id, 'ch_1');
    expect(details.playlists.map((p) => p.id), contains('pl_1'));
  });
}
