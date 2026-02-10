import 'package:app/app/providers/works_provider.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorksProvider', () {
    test('loads first page only when active', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);
      await dbService.ingestPlaylistItems([
        _item(id: 'wk_001', title: 'Work 1'),
        _item(id: 'wk_002', title: 'Work 2'),
      ]);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(worksProvider.notifier);
      expect(container.read(worksProvider).works, isEmpty);

      notifier.setActive(true);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final state = container.read(worksProvider);
      expect(state.works.length, 2);
      expect(state.isLoading, isFalse);
    });

    test('applies token updates with 1s debounce while active', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);
      await dbService.ingestPlaylistItems([
        _item(id: 'wk_001', title: 'Before'),
      ]);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(worksProvider.notifier);
      notifier.setActive(true);
      notifier.updateVisibleRange(startIndex: 0, endIndex: 0);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(container.read(worksProvider).works.first.title, 'Before');

      await dbService.ingestPlaylistItem(_item(id: 'wk_001', title: 'After'));

      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(container.read(worksProvider).works.first.title, 'Before');

      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(container.read(worksProvider).works.first.title, 'After');
    });

    test('does not react to item changes while inactive', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final dbService = DatabaseService(db);
      await dbService.ingestPlaylistItems([
        _item(id: 'wk_001', title: 'Before'),
      ]);

      final container = ProviderContainer.test(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => dbService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(worksProvider.notifier);
      notifier.setActive(true);
      notifier.updateVisibleRange(startIndex: 0, endIndex: 0);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(container.read(worksProvider).works.first.title, 'Before');

      notifier.setActive(false);
      await dbService.ingestPlaylistItem(_item(id: 'wk_001', title: 'After'));
      await Future<void>.delayed(const Duration(milliseconds: 1700));

      expect(container.read(worksProvider).works.first.title, 'Before');
    });
  });
}

PlaylistItem _item({
  required String id,
  required String title,
}) {
  return PlaylistItem(
    id: id,
    kind: PlaylistItemKind.indexerToken,
    title: title,
    updatedAt: DateTime.now(),
  );
}
