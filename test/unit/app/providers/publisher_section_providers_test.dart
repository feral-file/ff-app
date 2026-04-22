import 'package:app/app/providers/database_service_provider.dart';
import 'package:app/app/providers/publisher_section_providers.dart';
import 'package:app/app/providers/seed_database_ready_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReadySeedNotifier extends SeedDatabaseReadyNotifier {
  @override
  bool build() => true;
}

Future<void> _seedChannelsAndPublishers(AppDatabase db) async {
  await db.into(db.publishers).insert(
        PublishersCompanion.insert(
          id: const Value(2),
          title: 'Publisher Two',
          createdAtUs: BigInt.from(2),
          updatedAtUs: BigInt.from(2),
        ),
      );
  await db.into(db.publishers).insert(
        PublishersCompanion.insert(
          id: const Value(1),
          title: 'Publisher One',
          createdAtUs: BigInt.from(1),
          updatedAtUs: BigInt.from(1),
        ),
      );
  await db.into(db.channels).insert(
        ChannelsCompanion.insert(
          id: 'ch_a',
          type: ChannelType.dp1.index,
          publisherId: const Value(2),
          title: 'Channel A',
          createdAtUs: BigInt.from(1),
          updatedAtUs: BigInt.from(1),
        ),
      );
  await db.into(db.channels).insert(
        ChannelsCompanion.insert(
          id: 'ch_b',
          type: ChannelType.dp1.index,
          publisherId: const Value(1),
          title: 'Channel B',
          createdAtUs: BigInt.from(2),
          updatedAtUs: BigInt.from(2),
        ),
      );
  await db.into(db.channels).insert(
        ChannelsCompanion.insert(
          id: 'ch_c',
          type: ChannelType.dp1.index,
          publisherId: const Value(2),
          title: 'Channel C',
          createdAtUs: BigInt.from(3),
          updatedAtUs: BigInt.from(3),
        ),
      );
}

void main() {
  test('publishersProvider returns publishers in id order', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedChannelsAndPublishers(db);

    final container = ProviderContainer.test(
      overrides: [
        isSeedDatabaseReadyProvider.overrideWith(_ReadySeedNotifier.new),
        databaseServiceProvider.overrideWithValue(DatabaseService(db)),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(publishersProvider, (_, _) {});
    addTearDown(subscription.close);

    final result = await container.read(publishersProvider.future);

    expect(result.map((publisher) => publisher.id), [1, 2]);
  });

  test('channelsByPublisherProvider preserves source order', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedChannelsAndPublishers(db);

    final container = ProviderContainer.test(
      overrides: [
        isSeedDatabaseReadyProvider.overrideWith(_ReadySeedNotifier.new),
        databaseServiceProvider.overrideWithValue(DatabaseService(db)),
      ],
    );
    addTearDown(container.dispose);
    final subscription =
        container.listen(channelsByPublisherProvider(2), (_, _) {});
    addTearDown(subscription.close);

    final result = await container.read(channelsByPublisherProvider(2).future);

    expect(result.map((channel) => channel.id), ['ch_a', 'ch_c']);
  });
}
