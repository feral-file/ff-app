/// Waits for every future in [futures] without letting one failure cancel the
/// rest.
///
/// Used for grouped pull-to-refresh: bucket streams still expose failures via
/// [AsyncValue], while [RefreshIndicator.onRefresh] must complete.
Future<void> awaitParallelFuturesIgnoringErrors(
  Iterable<Future<void>> futures,
) {
  return Future.wait<void>(
    futures.map(
      (f) => f.catchError((Object _, StackTrace __) {}),
    ),
  );
}
