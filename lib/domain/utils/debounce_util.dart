import 'dart:async';

/// Map of blocking keys and their status.
Map<String, bool> _blocking = {};

/// Debounce a function call.
FutureOr<T> withDebounce<T>(
  FutureOr<T> Function() func, {
  String key = 'click',
  int debounceTime = 500,
}) {
  /// If the key is already blocked, throw an error.
  if (_blocking[key] ?? false) {
    throw StateError('Debounced action is blocked for key: $key');
  }

  _blocking[key] = true;

  /// Clear the blocking for the key.
  Future<void> clearBlocking() async {
    /// Wait for the debounce time.
    await Future<void>.delayed(Duration(milliseconds: debounceTime));
    _blocking.remove(key);
  }

  try {
    final result = func.call();

    if (result is Future<T>) {
      return result.whenComplete(clearBlocking);
    } else {
      clearBlocking();
      return result;
    }
  } catch (e) {
    clearBlocking();
    rethrow; // Re-throw the error for the caller to handle
  }
}
