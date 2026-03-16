import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:dart_duckdb/dart_duckdb.dart';
import 'package:dart_duckdb/open.dart';
import 'package:sqlite3/sqlite3.dart';

import 'benchmark_core.dart';
import 'duckdb_backend.dart';
import 'sqlite_backend.dart';

Future<void> main(List<String> args) async {
  final config = _parseArgs(args);
  final databaseFile = File(config.databasePath);
  if (!databaseFile.existsSync()) {
    stderr.writeln('Database not found: ${config.databasePath}');
    exitCode = 1;
    return;
  }

  switch (config.backend) {
    case 'sqlite':
      await _runSqliteBenchmark(config);
      return;
    case 'duckdb':
      await _runDuckDBBenchmark(config);
      return;
    default:
      throw UnsupportedError(
        'Unsupported backend "${config.backend}". '
        'Add a backend adapter under autoresearch/scripts/ to enable it.',
      );
  }
}

Future<void> _runSqliteBenchmark(_BenchmarkConfig config) async {
  final db = sqlite3.open(config.databasePath);
  final backend = SqliteBenchmarkBackend(
    db: db
      ..execute('PRAGMA busy_timeout = 5000')
      ..execute('PRAGMA journal_mode = WAL'),
    databasePath: config.databasePath,
  );

  try {
    final benchmark = await summarizeBenchmark(
      label: config.label,
      backend: backend.backendName,
      databasePath: config.databasePath,
      scenarios: backend.buildScenarios(),
    );
    final json = const JsonEncoder.withIndent('  ').convert(benchmark);
    if (config.outputPath != null) {
      File(config.outputPath!).writeAsStringSync('$json\n');
    }
    stdout.writeln(json);
  } finally {
    backend.dispose();
  }
}

Future<void> _runDuckDBBenchmark(_BenchmarkConfig config) async {
  // For standalone Dart (not a Flutter build), point to the system DuckDB
  // installed via Homebrew. Flutter builds bundle the DuckDB binary.
  if (Platform.isMacOS) {
    const homebrew = '/opt/homebrew/lib/libduckdb.dylib';
    if (File(homebrew).existsSync()) {
      open.overrideFor(OperatingSystem.macOS, homebrew);
    }
  }

  final db = await duckdb.open(config.databasePath);
  final conn = await duckdb.connect(db);
  final backend = DuckDBBenchmarkBackend(
    conn: conn,
    databasePath: config.databasePath,
  );

  try {
    final scenarios = await backend.buildScenarios();
    final benchmark = await summarizeBenchmark(
      label: config.label,
      backend: backend.backendName,
      databasePath: config.databasePath,
      scenarios: scenarios,
    );
    final json = const JsonEncoder.withIndent('  ').convert(benchmark);
    if (config.outputPath != null) {
      File(config.outputPath!).writeAsStringSync('$json\n');
    }
    stdout.writeln(json);
  } finally {
    await backend.dispose();
    await db.dispose();
  }
}

_BenchmarkConfig _parseArgs(List<String> args) {
  String? databasePath;
  String? label;
  String? outputPath;
  var backend = 'sqlite';

  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    final next = index + 1 < args.length ? args[index + 1] : null;

    if (arg == '--database') {
      databasePath = next;
      index += 1;
      continue;
    }
    if (arg == '--label') {
      label = next;
      index += 1;
      continue;
    }
    if (arg == '--output') {
      outputPath = next;
      index += 1;
      continue;
    }
    if (arg == '--backend') {
      backend = next ?? backend;
      index += 1;
      continue;
    }
    if (arg.startsWith('-')) {
      throw ArgumentError('Unknown argument: $arg');
    }
  }

  if (databasePath == null || databasePath.isEmpty) {
    throw ArgumentError('Missing required --database argument');
  }

  return _BenchmarkConfig(
    databasePath: databasePath,
    label: label ?? 'candidate',
    outputPath: outputPath,
    backend: backend,
  );
}

class _BenchmarkConfig {
  const _BenchmarkConfig({
    required this.databasePath,
    required this.label,
    required this.outputPath,
    required this.backend,
  });

  final String databasePath;
  final String label;
  final String? outputPath;
  final String backend;
}
