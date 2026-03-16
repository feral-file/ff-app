import 'package:isar/isar.dart';

part 'schema.g.dart';

// ---------------------------------------------------------------------------
// IsarChannel
// ---------------------------------------------------------------------------

@Collection()
class IsarChannel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String channelId;

  // FTS: multi-entry index over title words for prefix search.
  @Index(type: IndexType.value, caseSensitive: false)
  List<String> get titleWords => _splitWords(title);

  late String title;
  late int type;

  // Non-null sentinel sort fields (null → 2147483647) so Isar ascending
  // sort matches SQLite's COALESCE(x, 2147483647) ASC without NULLS LAST.
  @Index()
  late int publisherOrder;
  late int sortOrderNorm;
  int? createdAtUs;

  // Full JSON payload for detail view (no JOIN needed).
  late String dataJson;
}

// ---------------------------------------------------------------------------
// IsarPlaylist
// ---------------------------------------------------------------------------

@Collection()
class IsarPlaylist {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String playlistId;

  @Index(type: IndexType.value, caseSensitive: false)
  List<String> get titleWords => _splitWords(title);

  late String title;
  late int type;
  late String channelId;
  late int sortMode;
  late int itemCount;
  late int createdAtUs;

  // Denormalized publisher_id from parent channel — eliminates JOIN for list.
  @Index()
  late int publisherOrder;

  late String dataJson;
}

// ---------------------------------------------------------------------------
// IsarWork
//
// The composite index mirrors SQLite's item_order_cache: sort by
// (publisherOrder, channelCreatedAtOrder, playlistCreatedAtOrder, workId).
// Isar uses this for the works list without a CTE.
// ---------------------------------------------------------------------------

@Collection()
class IsarWork {
  // FNV-1a hash of workId as the Isar integer Id enables O(1) getAll() batch
  // fetches by workId without a secondary where() index scan.
  Id get id => _fnv1aHash(workId);

  late String workId;

  // Composite index for the works ordered-list query (max 3 fields in Isar).
  // Tiebreaker on workId is handled at query time via .thenByWorkId().
  @Index(
    composite: [
      CompositeIndex('channelCreatedAtOrder'),
      CompositeIndex('playlistCreatedAtOrder'),
    ],
  )
  late int publisherOrder;
  late int channelCreatedAtOrder;
  late int playlistCreatedAtOrder;

  // FTS over title and artist fields.
  @Index(type: IndexType.value, caseSensitive: false)
  List<String> get titleWords => _splitWords(title);

  @Index(type: IndexType.value, caseSensitive: false)
  List<String> get artistWords => _splitWords(listArtistJson ?? '');

  late int kind;
  late String title;
  String? listArtistJson;
  String? thumbnailUri;
  String? subtitle;
  int? durationSec;
  int? enrichmentStatus;
  int? updatedAtUs;

  // Slim JSON for list view (excludes token_data_json).
  late String headJson;

  // Full JSON for detail view (includes token_data_json).
  late String dataJson;
}

// ---------------------------------------------------------------------------
// IsarPlaylistEntry
// ---------------------------------------------------------------------------

@Collection()
class IsarPlaylistEntry {
  Id id = Isar.autoIncrement;

  @Index()
  late String playlistId;

  late String workId;
  int? position;
  int? sortKeyUs;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// FNV-1a 64-bit hash, masked to a positive signed 63-bit int for Isar.
/// Stable across runs — no random seed.
int _fnv1aHash(String input) {
  const prime = 0x00000100000001b3;
  var hash = 0xcbf29ce484222325;
  for (final char in input.codeUnits) {
    hash ^= char;
    hash = (hash * prime) & 0x7fffffffffffffff; // keep positive signed 63-bit
  }
  return hash == 0 ? 1 : hash;
}

List<String> _splitWords(String text) {
  // Strip JSON brackets/quotes that appear in list_artist_json.
  final cleaned = text.replaceAll(RegExp(r'[\[\]"{}]'), ' ');
  return cleaned
      .toLowerCase()
      .split(RegExp(r'[\s,;]+'))
      .where((w) => w.length >= 2)
      .toSet()
      .toList(growable: false);
}
