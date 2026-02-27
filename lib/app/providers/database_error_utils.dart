/// Returns true when [error] indicates SQLite is unavailable during reset.
bool isDatabaseUnavailableError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('database has been closed') ||
      message.contains('database is closed') ||
      message.contains('unable to open database file') ||
      message.contains('no such table') ||
      message.contains('bad state: this database is no longer open');
}
