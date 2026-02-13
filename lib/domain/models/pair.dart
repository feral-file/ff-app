/// General-purpose pair of two values.
/// Used for FeedManager storage, canvas notification manager, and similar.
class Pair<T1, T2> {
  Pair(this.first, this.second);

  T1 first;
  T2 second;
}
