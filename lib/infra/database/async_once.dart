class AsyncOnce<T> {
  Future<T>? _inFlight;
  T? _value;

  bool get hasValue => _value != null;

  T get value {
    final value = _value;
    if (value == null) {
      throw StateError('Value has not been initialized yet.');
    }
    return value;
  }

  Future<T> run(Future<T> Function() task) {
    final existingValue = _value;
    if (existingValue != null) {
      return Future<T>.value(existingValue);
    }

    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final created = task();
    _inFlight = created;
    return created.then((value) {
      _value = value;
      return value;
    }).whenComplete(() {
      _inFlight = null;
    });
  }

  void reset() {
    _value = null;
    _inFlight = null;
  }
}
