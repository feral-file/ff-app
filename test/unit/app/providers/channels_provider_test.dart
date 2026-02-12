import 'package:app/app/providers/channels_provider.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for channels provider (family by ChannelType).
void main() {
  group('ChannelsProvider (family by ChannelType)', () {
    test('dp1 provider returns initial state with empty channels', () {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(channelsProvider(ChannelType.dp1));

      expect(state.channels, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isTrue);
      expect(state.cursor, isNull);
      expect(state.error, isNull);
    });

    test('localVirtual provider returns initial state with empty channels', () {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(channelsProvider(ChannelType.localVirtual));

      expect(state.channels, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.cursor, isNull);
    });

    test('loadChannels for dp1 completes and updates state', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(channelsProvider(ChannelType.dp1).notifier)
          .loadChannels();

      final state = container.read(channelsProvider(ChannelType.dp1));
      expect(state.channels, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
    });

    test('loadChannels for localVirtual completes and updates state', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(channelsProvider(ChannelType.localVirtual).notifier)
          .loadChannels();

      final state = container.read(channelsProvider(ChannelType.localVirtual));
      expect(state.channels, isEmpty);
      expect(state.isLoading, isFalse);
    });
  });
}
