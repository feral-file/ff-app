/// Returns true when [error] indicates SQLite/Drift is unavailable during reset.
///
/// Includes Drift isolate channel closure ("channel was closed",
/// "connection was closed"), Stream.firstWhere "No element" when isolate shuts
/// down, and CouldNotRollBackException during Forget I Exist or similar flows.
bool isDatabaseUnavailableError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('database has been closed') ||
      message.contains('database is closed') ||
      message.contains('channel was closed') ||
      message.contains('connection was closed') ||
      message.contains('unable to open database file') ||
      message.contains('no such table') ||
      message.contains('bad state: this database is no longer open') ||
      message.contains('bad state: no element') ||
      message.contains('couldnotrollbackexception');
}
