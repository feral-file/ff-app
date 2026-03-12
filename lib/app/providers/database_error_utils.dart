/// Returns true when [error] indicates SQLite/Drift is unavailable during reset.
///
/// Includes Drift isolate channel closure ("channel was closed") which occurs
/// when the database is closed during "Forget I Exist" or similar cleanup flows.
bool isDatabaseUnavailableError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('database has been closed') ||
      message.contains('database is closed') ||
      message.contains('channel was closed') ||
      message.contains('unable to open database file') ||
      message.contains('no such table') ||
      message.contains('bad state: this database is no longer open');
}
