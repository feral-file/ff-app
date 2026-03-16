import 'dart:async';

typedef ScenarioRunner = FutureOr<Object?> Function();

class BenchmarkScenario {
  BenchmarkScenario({
    required this.name,
    required this.runner,
  });

  final String name;
  final ScenarioRunner runner;
}

Future<Map<String, Object?>> summarizeBenchmark({
  required String label,
  required String backend,
  required String databasePath,
  required List<BenchmarkScenario> scenarios,
}) async {
  final results = <Map<String, Object?>>[];
  // Run scenarios sequentially so page cache warms up naturally.
  for (final scenario in scenarios) {
    results.add(await measureScenario(scenario.name, scenario.runner));
  }

  final avgP95Ms = _round3(
    results.fold<double>(
          0,
          (sum, scenario) => sum + (scenario['p95Ms']! as double),
        ) /
        results.length,
  );
  final maxP95Ms = _round3(
    results
        .map((scenario) => scenario['p95Ms']! as double)
        .reduce((left, right) => left > right ? left : right),
  );

  return {
    'label': label,
    'backend': backend,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'databasePath': databasePath,
    'scenarioCount': results.length,
    'avgP95Ms': avgP95Ms,
    'maxP95Ms': maxP95Ms,
    'scenarios': results,
  };
}

Future<Map<String, Object?>> measureScenario(
  String name,
  ScenarioRunner action, {
  int warmupRuns = 3,
  int measuredRuns = 30,
}) async {
  for (var index = 0; index < warmupRuns; index += 1) {
    await action();
  }

  final samples = <double>[];
  for (var index = 0; index < measuredRuns; index += 1) {
    final stopwatch = Stopwatch()..start();
    await action();
    stopwatch.stop();
    samples.add(stopwatch.elapsedMicroseconds / 1000);
  }
  samples.sort();

  return {
    'name': name,
    'iterations': measuredRuns,
    'minMs': _round3(samples.first),
    'p50Ms': _round3(_percentile(samples, 0.50)),
    'p95Ms': _round3(_percentile(samples, 0.95)),
    'maxMs': _round3(samples.last),
    'meanMs': _round3(
      samples.reduce((sum, value) => sum + value) / samples.length,
    ),
  };
}

double _percentile(List<double> sortedValues, double percentile) {
  if (sortedValues.isEmpty) {
    return 0;
  }
  if (sortedValues.length == 1) {
    return sortedValues.first;
  }
  final rawIndex = percentile * (sortedValues.length - 1);
  final lowerIndex = rawIndex.floor();
  final upperIndex = rawIndex.ceil();
  if (lowerIndex == upperIndex) {
    return sortedValues[lowerIndex];
  }
  final ratio = rawIndex - lowerIndex;
  return sortedValues[lowerIndex] * (1 - ratio) +
      sortedValues[upperIndex] * ratio;
}

double _round3(double value) => (value * 1000).round() / 1000;
