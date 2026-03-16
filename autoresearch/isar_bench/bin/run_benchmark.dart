/// Runs benchmark scenarios against an Isar database and outputs JSON in the
/// same format as the SQLite/DuckDB benchmarks.
///
/// Usage (from autoresearch/isar_bench/):
///   dart run bin/run_benchmark.dart \
///     --database <dir_path> --label <name> [--output <json_file>]
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path/path.dart' as p;

import '../lib/schema.dart';

Future<void> main(List<String> args) async {
  String? dbDir, label, outputPath;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--database') dbDir = args[i + 1];
    if (args[i] == '--label') label = args[i + 1];
    if (args[i] == '--output') outputPath = args[i + 1];
  }
  if (dbDir == null) throw ArgumentError('Missing --database <dir>');
  label ??= 'isar_candidate';

  await Isar.initializeIsarCore(
    libraries: {Abi.macosArm64: _findIsarLib()},
  );

  final isar = await Isar.open(
    [
      IsarChannelSchema,
      IsarPlaylistSchema,
      IsarWorkSchema,
      IsarPlaylistEntrySchema,
    ],
    directory: dbDir,
    name: 'isar_bench',
    inspector: false,
  );

  try {
    final result = await _runBenchmark(isar, label, dbDir);
    final json = const JsonEncoder.withIndent('  ').convert(result);
    if (outputPath != null) File(outputPath).writeAsStringSync('$json\n');
    stdout.writeln(json);
  } finally {
    await isar.close();
  }
}

Future<Map<String, Object?>> _runBenchmark(
  Isar isar,
  String label,
  String dbDir,
) async {
  // ── seed sample values ────────────────────────────────────────────────────
  final seedChannels = isar.isarChannels
      .filter()
      .typeEqualTo(0)
      .sortByPublisherOrder()
      .thenBySortOrderNorm()
      .thenByChannelId()
      .limit(20)
      .findAllSync();

  final seedPlaylists = isar.isarPlaylists
      .filter()
      .typeEqualTo(0)
      .sortByPublisherOrder()
      .thenByCreatedAtUs()
      .limit(20)
      .findAllSync();

  final seedWorkIds = _getWorkIds(isar, limit: 100, offset: 0);

  if (seedChannels.isEmpty || seedPlaylists.isEmpty || seedWorkIds.isEmpty) {
    throw StateError('Seed queries returned empty results');
  }

  final posPlaylist = seedPlaylists.firstWhere(
    (pl) => pl.sortMode == 0,
    orElse: () => seedPlaylists.first,
  );
  final provPlaylist = seedPlaylists.firstWhere(
    (pl) => pl.sortMode == 1,
    orElse: () => posPlaylist,
  );

  final sChannelId = seedChannels.first.channelId;
  final sChannelTitle = seedChannels.first.title;
  final sPlaylistId = posPlaylist.playlistId;
  final sPlaylistTitle = posPlaylist.title;
  final sProvPlaylistId = provPlaylist.playlistId;
  final sWorkId = seedWorkIds.first;
  final sWorkTitle = isar.isarWorks.getSync(_fnv1aHash(sWorkId))?.title ?? '';

  // ── scenarios ─────────────────────────────────────────────────────────────
  final scenarios = [
    _Scenario(
      'channels.dp1.page1.limit11',
      () => isar.isarChannels
          .filter()
          .typeEqualTo(0)
          .sortByPublisherOrder()
          .thenBySortOrderNorm()
          .thenByChannelId()
          .offset(0)
          .limit(11)
          .findAllSync(),
    ),
    _Scenario(
      'channels.dp1.page2.limit10',
      () => isar.isarChannels
          .filter()
          .typeEqualTo(0)
          .sortByPublisherOrder()
          .thenBySortOrderNorm()
          .thenByChannelId()
          .offset(10)
          .limit(10)
          .findAllSync(),
    ),
    _Scenario(
      'playlists.dp1.all',
      () => isar.isarPlaylists
          .filter()
          .typeEqualTo(0)
          .sortByPublisherOrder()
          .thenByCreatedAtUs()
          .findAllSync(),
    ),
    _Scenario(
      'channel.detail',
      () => isar.isarChannels.where().channelIdEqualTo(sChannelId).findFirstSync(),
    ),
    _Scenario(
      'playlist.detail',
      () => isar.isarPlaylists.where().playlistIdEqualTo(sPlaylistId).findFirstSync(),
    ),
    _Scenario(
      'playlist.items.position.page1',
      () {
        final entries = isar.isarPlaylistEntrys
            .where()
            .playlistIdEqualTo(sPlaylistId)
            .sortByPosition()
            .thenByWorkId()
            .offset(0)
            .limit(20)
            .findAllSync();
        return _fetchWorksByIds(isar, entries.map((e) => e.workId).toList());
      },
    ),
    _Scenario(
      'playlist.items.position.full',
      () {
        final entries = isar.isarPlaylistEntrys
            .where()
            .playlistIdEqualTo(sPlaylistId)
            .sortByPosition()
            .thenByWorkId()
            .findAllSync();
        return _fetchWorksByIds(isar, entries.map((e) => e.workId).toList());
      },
    ),
    _Scenario(
      'playlist.items.provenance.page1',
      () {
        final entries = isar.isarPlaylistEntrys
            .where()
            .playlistIdEqualTo(sProvPlaylistId)
            .sortBySortKeyUsDesc()
            .offset(0)
            .limit(20)
            .findAllSync();
        return _fetchWorksByIds(isar, entries.map((e) => e.workId).toList());
      },
    ),
    _Scenario(
      'channel.preview.page1',
      () {
        final pls = isar.isarPlaylists
            .filter()
            .channelIdEqualTo(sChannelId)
            .sortByCreatedAtUs()
            .findAllSync();
        final seen = <String>{};
        final ids = <String>[];
        for (final pl in pls) {
          if (ids.length >= 25) break;
          final entries = isar.isarPlaylistEntrys
              .where()
              .playlistIdEqualTo(pl.playlistId)
              .sortByPosition()
              .findAllSync();
          for (final e in entries) {
            if (ids.length >= 25) break;
            if (seen.add(e.workId)) ids.add(e.workId);
          }
        }
        return _fetchWorksByIds(isar, ids);
      },
    ),
    _Scenario(
      'works.page1',
      () {
        final ids = _getWorkIds(isar, limit: 51, offset: 0);
        return _fetchWorksByIds(isar, ids);
      },
    ),
    _Scenario(
      'works.ids.page1',
      () => _getWorkIds(isar, limit: 51, offset: 0),
    ),
    _Scenario(
      'work.detail',
      () => isar.isarWorks.getSync(_fnv1aHash(sWorkId)),
    ),
    _Scenario(
      'search.channels.suggestions',
      () {
        final tok = _firstToken(sChannelTitle);
        return isar.isarChannels
            .where()
            .titleWordsElementStartsWith(tok)
            .limit(4)
            .findAllSync();
      },
    ),
    _Scenario(
      'search.playlists.suggestions',
      () {
        final tok = _firstToken(sPlaylistTitle);
        return isar.isarPlaylists
            .where()
            .titleWordsElementStartsWith(tok)
            .limit(4)
            .findAllSync();
      },
    ),
    _Scenario(
      'search.items.suggestions',
      () {
        final tok = _firstToken(sWorkTitle);
        return isar.isarWorks
            .where()
            .titleWordsElementStartsWith(tok)
            .limit(6)
            .findAllSync();
      },
    ),
    _Scenario(
      'search.items.results',
      () {
        final tok = _firstToken(sWorkTitle);
        return isar.isarWorks
            .where()
            .titleWordsElementStartsWith(tok)
            .limit(40)
            .findAllSync();
      },
    ),
  ];

  // ── measure ───────────────────────────────────────────────────────────────
  final results = [for (final s in scenarios) _measure(s)];

  final avgP95 = _round3(
    results.fold<double>(0, (sum, r) => sum + (r['p95Ms']! as double)) /
        results.length,
  );
  final maxP95 = _round3(
    results
        .map((r) => r['p95Ms']! as double)
        .reduce((a, b) => a > b ? a : b),
  );

  final dbFile = File(p.join(dbDir, 'isar_bench.isar'));
  return {
    'label': label,
    'backend': 'isar',
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'databasePath': dbDir,
    'databaseSizeBytes': dbFile.existsSync() ? dbFile.lengthSync() : 0,
    'scenarioCount': results.length,
    'avgP95Ms': avgP95,
    'maxP95Ms': maxP95,
    'scenarios': results,
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<String> _getWorkIds(Isar isar, {required int limit, required int offset}) =>
    // any() over the composite index returns records in index order — no
    // additional sortBy() needed (that would force an in-memory re-sort of
    // all records, bypassing the index entirely).
    isar.isarWorks
        .where()
        .anyPublisherOrderChannelCreatedAtOrderPlaylistCreatedAtOrder()
        .offset(offset)
        .limit(limit)
        .findAllSync()
        .map((w) => w.workId)
        .toList(growable: false);

List<IsarWork> _fetchWorksByIds(Isar isar, List<String> ids) {
  if (ids.isEmpty) return const [];
  // getAll() by FNV-1a hash id is O(n) B-tree lookups instead of O(n log M)
  // for anyOf() where clauses — significantly faster for large batches.
  final hashIds = ids.map(_fnv1aHash).toList(growable: false);
  return isar.isarWorks.getAllSync(hashIds).whereType<IsarWork>().toList(growable: false);
}

int _fnv1aHash(String input) {
  const prime = 0x00000100000001b3;
  var hash = 0xcbf29ce484222325;
  for (final char in input.codeUnits) {
    hash ^= char;
    hash = (hash * prime) & 0x7fffffffffffffff;
  }
  return hash == 0 ? 1 : hash;
}

Map<String, Object?> _measure(
  _Scenario scenario, {
  int warmup = 3,
  int measured = 30,
}) {
  for (var i = 0; i < warmup; i++) scenario.runner();
  final samples = <double>[];
  for (var i = 0; i < measured; i++) {
    final sw = Stopwatch()..start();
    scenario.runner();
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000);
  }
  samples.sort();
  return {
    'name': scenario.name,
    'iterations': measured,
    'minMs': _round3(samples.first),
    'p50Ms': _round3(_pct(samples, .50)),
    'p95Ms': _round3(_pct(samples, .95)),
    'maxMs': _round3(samples.last),
    'meanMs': _round3(samples.reduce((a, b) => a + b) / samples.length),
  };
}

double _pct(List<double> s, double p) {
  final raw = p * (s.length - 1);
  final lo = raw.floor(), hi = raw.ceil();
  return lo == hi ? s[lo] : s[lo] * (1 - raw + lo) + s[hi] * (raw - lo);
}

double _round3(double v) => (v * 1000).round() / 1000;

String _firstToken(String text) {
  final t = text
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .map((s) => s.replaceAll(RegExp('[^a-z0-9]'), ''))
      .firstWhere((s) => s.length >= 2, orElse: () => 'art');
  return t;
}

String _findIsarLib() {
  final home = Platform.environment['HOME'] ?? '';
  final path = p.join(
    home, '.pub-cache', 'hosted', 'pub.dev',
    'isar_flutter_libs-3.1.0+1', 'macos', 'libisar.dylib',
  );
  if (!File(path).existsSync()) throw StateError('libisar.dylib not found: $path');
  return path;
}

class _Scenario {
  _Scenario(this.name, this.runner);
  final String name;
  final Object? Function() runner;
}
