import 'package:app/app/bootstrap/app_bootstrap.dart';
import 'package:app/infra/database/seed_database_gate.dart';
import 'package:app/infra/services/seed_database_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _GateSeedDatabaseServiceFake extends SeedDatabaseService {
  _GateSeedDatabaseServiceFake({required this.hasUsableDatabase});

  final bool hasUsableDatabase;

  @override
  Future<bool> hasUsableLocalDatabase() async => hasUsableDatabase;
}

void main() {
  setUp(SeedDatabaseGate.resetForTesting);

  test(
    'completeSeedDatabaseGateIfUsable opens the gate when database is valid',
    () async {
      final service = _GateSeedDatabaseServiceFake(hasUsableDatabase: true);

      await completeSeedDatabaseGateIfUsable(service);

      expect(SeedDatabaseGate.isCompleted, isTrue);
    },
  );

  test(
    'completeSeedDatabaseGateIfUsable keeps gate closed when database is invalid',
    () async {
      final service = _GateSeedDatabaseServiceFake(hasUsableDatabase: false);

      await completeSeedDatabaseGateIfUsable(service);

      expect(SeedDatabaseGate.isCompleted, isFalse);
    },
  );
}
