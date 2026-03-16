/// Builds an Isar database from the SQLite baseline.
///
/// Usage (from autoresearch/isar_bench/):
///   dart run bin/build_db.dart \
///     --candidate <name> \
///     --output  <dir_path> \
///     --baseline <path.sqlite>
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sq;

import '../lib/schema.dart';

Future<void> main(List<String> args) async {
  final String candidate;
  final String outputDir;
  final String baselinePath;

  // Parse args.
  String? c, o, b;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--candidate') c = args[i + 1];
    if (args[i] == '--output') o = args[i + 1];
    if (args[i] == '--baseline') b = args[i + 1];
  }
  if (c == null || o == null || b == null) {
    throw ArgumentError('Usage: --candidate <n> --output <dir> --baseline <sqlite>');
  }
  candidate = c;
  outputDir = o;
  baselinePath = b;

  // Point to the libisar.dylib from the isar_flutter_libs pub-cache entry.
  // For Flutter app builds, the library is bundled automatically.
  final isarLib = _findIsarLib();
  await Isar.initializeIsarCore(libraries: {Abi.macosArm64: isarLib});

  // Fresh output directory.
  final dir = Directory(outputDir);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  dir.createSync(recursive: true);

  final sqlite = sq.sqlite3.open(baselinePath, mode: sq.OpenMode.readOnly);
  final isar = await Isar.open(
    [
      IsarChannelSchema,
      IsarPlaylistSchema,
      IsarWorkSchema,
      IsarPlaylistEntrySchema,
    ],
    directory: outputDir,
    name: 'isar_bench',
    inspector: false,
  );

  try {
    stderr.writeln('Building candidate: $candidate');
    await _importChannels(sqlite, isar);
    await _importPlaylists(sqlite, isar);
    await _importWorks(sqlite, isar);
    await _importPlaylistEntries(sqlite, isar);
    stderr.writeln('Done. Output: $outputDir');
  } finally {
    sqlite.dispose();
    await isar.close();
  }
}

// ---------------------------------------------------------------------------
// Channels
// ---------------------------------------------------------------------------

Future<void> _importChannels(sq.Database sqlite, Isar isar) async {
  final rows = sqlite.select(
    'SELECT id, title, type, publisher_id, sort_order, created_at_us FROM channels',
  );
  final channels = <IsarChannel>[];
  for (final row in rows) {
    channels.add(
      IsarChannel()
        ..channelId = row['id'] as String
        ..title = row['title'] as String? ?? ''
        ..type = (row['type'] as int?) ?? 0
        ..publisherOrder = (row['publisher_id'] as int?) ?? 2147483647
        ..sortOrderNorm = (row['sort_order'] as int?) ?? 2147483647
        ..createdAtUs = row['created_at_us'] as int?
        ..dataJson = _rowToJson(row),
    );
  }
  await isar.writeTxn(() => isar.isarChannels.putAll(channels));
  stderr.writeln('  channels: ${channels.length}');
}

// ---------------------------------------------------------------------------
// Playlists — publisherOrder denormalized from parent channel
// ---------------------------------------------------------------------------

Future<void> _importPlaylists(sq.Database sqlite, Isar isar) async {
  final rows = sqlite.select(
    '''
    SELECT
      p.id, p.title, p.type, p.channel_id, p.sort_mode,
      p.item_count, p.created_at_us,
      COALESCE(c.publisher_id, 2147483647) AS publisher_order
    FROM playlists p
    LEFT JOIN channels c ON c.id = p.channel_id
    ''',
  );
  final playlists = <IsarPlaylist>[];
  for (final row in rows) {
    playlists.add(
      IsarPlaylist()
        ..playlistId = row['id'] as String
        ..title = row['title'] as String? ?? ''
        ..type = (row['type'] as int?) ?? 0
        ..channelId = row['channel_id'] as String? ?? ''
        ..sortMode = (row['sort_mode'] as int?) ?? 0
        ..itemCount = (row['item_count'] as int?) ?? 0
        ..createdAtUs = (row['created_at_us'] as int?) ?? 0
        ..publisherOrder = row['publisher_order'] as int
        ..dataJson = _rowToJson(row),
    );
  }
  await isar.writeTxn(() => isar.isarPlaylists.putAll(playlists));
  stderr.writeln('  playlists: ${playlists.length}');
}

// ---------------------------------------------------------------------------
// Works — precomputed sort orders embedded (equivalent to item_order_cache)
// ---------------------------------------------------------------------------

Future<void> _importWorks(sq.Database sqlite, Isar isar) async {
  // Precompute per-work sort position using the same formula as item_order_cache.
  final orderRows = sqlite.select(
    '''
    SELECT
      pe.item_id AS work_id,
      MIN(COALESCE(c.publisher_id, 2147483647)) AS publisher_order,
      MIN(COALESCE(c.created_at_us, 9223372036854775807)) AS channel_order,
      MIN(COALESCE(p.created_at_us, 9223372036854775807)) AS playlist_order
    FROM playlist_entries pe
    JOIN playlists p ON p.id = pe.playlist_id
    LEFT JOIN channels c ON c.id = p.channel_id
    GROUP BY pe.item_id
    ''',
  );
  final publisherOrderMap = <String, int>{};
  final channelOrderMap = <String, int>{};
  final playlistOrderMap = <String, int>{};
  for (final r in orderRows) {
    final id = r['work_id'] as String;
    publisherOrderMap[id] = r['publisher_order'] as int;
    channelOrderMap[id] = r['channel_order'] as int;
    playlistOrderMap[id] = r['playlist_order'] as int;
  }

  final rows = sqlite.select('SELECT * FROM items');
  final works = <IsarWork>[];
  for (final row in rows) {
    final id = row['id'] as String;
    final head = <String, Object?>{
      'id': id,
      'kind': row['kind'],
      'title': row['title'],
      'subtitle': row['subtitle'],
      'thumbnail_uri': row['thumbnail_uri'],
      'duration_sec': row['duration_sec'],
      'list_artist_json': row['list_artist_json'],
      'enrichment_status': row['enrichment_status'],
      'updated_at_us': row['updated_at_us'],
    };
    works.add(
      IsarWork()
        ..workId = id
        ..kind = (row['kind'] as int?) ?? 0
        ..title = row['title'] as String? ?? ''
        ..listArtistJson = row['list_artist_json'] as String?
        ..thumbnailUri = row['thumbnail_uri'] as String?
        ..subtitle = row['subtitle'] as String?
        ..durationSec = row['duration_sec'] as int?
        ..enrichmentStatus = row['enrichment_status'] as int?
        ..updatedAtUs = row['updated_at_us'] as int?
        ..publisherOrder = publisherOrderMap[id] ?? 2147483647
        ..channelCreatedAtOrder = channelOrderMap[id] ?? 9223372036854775807
        ..playlistCreatedAtOrder = playlistOrderMap[id] ?? 9223372036854775807
        ..headJson = jsonEncode(head)
        ..dataJson = _rowToJson(row),
    );
  }

  // Write in batches of 500 to avoid large transactions.
  for (var offset = 0; offset < works.length; offset += 500) {
    final end = (offset + 500).clamp(0, works.length);
    await isar.writeTxn(() => isar.isarWorks.putAll(works.sublist(offset, end)));
  }
  stderr.writeln('  works: ${works.length}');
}

// ---------------------------------------------------------------------------
// PlaylistEntries
// ---------------------------------------------------------------------------

Future<void> _importPlaylistEntries(sq.Database sqlite, Isar isar) async {
  final rows = sqlite.select(
    'SELECT playlist_id, item_id, position, sort_key_us FROM playlist_entries',
  );
  final entries = <IsarPlaylistEntry>[];
  for (final row in rows) {
    entries.add(
      IsarPlaylistEntry()
        ..playlistId = row['playlist_id'] as String
        ..workId = row['item_id'] as String
        ..position = row['position'] as int?
        ..sortKeyUs = row['sort_key_us'] as int?,
    );
  }
  await isar.writeTxn(() => isar.isarPlaylistEntrys.putAll(entries));
  stderr.writeln('  playlist_entries: ${entries.length}');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _findIsarLib() {
  final home = Platform.environment['HOME'] ?? '';
  final path = p.join(
    home,
    '.pub-cache',
    'hosted',
    'pub.dev',
    'isar_flutter_libs-3.1.0+1',
    'macos',
    'libisar.dylib',
  );
  if (!File(path).existsSync()) {
    throw StateError(
      'libisar.dylib not found at $path. '
      'Run `dart pub get` in autoresearch/isar_bench/ to populate the pub cache.',
    );
  }
  return path;
}

String _rowToJson(sq.Row row) {
  final map = <String, Object?>{};
  for (final key in row.keys) {
    map[key] = row[key];
  }
  return jsonEncode(map);
}
