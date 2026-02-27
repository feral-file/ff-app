import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/objectbox.g.dart' show RemoteAppConfigEntity_;
import 'package:objectbox/objectbox.dart';

/// Stores seed-database sync metadata in ObjectBox app config storage.
///
/// Reuses [RemoteAppConfigEntity] with a separate scope row to avoid adding a
/// new ObjectBox entity/schema for one ETag field.
class SeedDatabaseConfigStore {
  /// Creates a store bound to the shared app-config ObjectBox box.
  SeedDatabaseConfigStore(this._box);

  /// ObjectBox scope key used for seed DB metadata rows.
  static const seedDatabaseScope = 'seed_database';

  final Box<RemoteAppConfigEntity> _box;

  /// Returns the last persisted seed DB ETag (empty when unavailable).
  String loadSeedEtag() {
    final entity = _getEntity();
    if (entity == null) return '';
    return entity.etag.trim();
  }

  /// Persists the latest seed DB ETag for startup sync comparisons.
  void saveSeedEtag(String etag) {
    final existing = _getEntity();
    final nowUs = DateTime.now().toUtc().microsecondsSinceEpoch;
    final entity = RemoteAppConfigEntity(
      scope: seedDatabaseScope,
      etag: etag.trim(),
      curatedChannelUrlsJson: existing?.curatedChannelUrlsJson ?? '[]',
      feedCacheDurationSec: existing?.feedCacheDurationSec ?? 0,
      feedLastUpdatedAtUs: existing?.feedLastUpdatedAtUs ?? 0,
      updatedAtUs: nowUs,
    )..id = existing?.id ?? 0;
    _box.put(entity);
  }

  RemoteAppConfigEntity? _getEntity() {
    final query = _box
        .query(RemoteAppConfigEntity_.scope.equals(seedDatabaseScope))
        .build();
    try {
      return query.findFirst();
    } finally {
      query.close();
    }
  }
}
