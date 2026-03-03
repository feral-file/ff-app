/// General-purpose pair of two values.
/// Used for canvas notification manager and similar key-value storage.
class Pair<T1, T2> {
  Pair(this.first, this.second);

  T1 first;
  T2 second;
}
