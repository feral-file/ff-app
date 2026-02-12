import 'package:app/app/providers/playlist_details_provider.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_provider.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('playlistDetailsProvider starts in loading state', () {
    // Unit test: verifies playlist details provider initializes with AsyncLoading.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer.test(
      overrides: [
        databaseServiceProvider.overrideWith((ref) => DatabaseService(db)),
      ],
    );
    addTearDown(container.dispose);

    final state = container.read(playlistDetailsProvider('pl_missing'));
    expect(state, isA<AsyncLoading<PlaylistDetailsState>>());
  });
}
