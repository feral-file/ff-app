/// Simple pair of two values.
/// Matches old repo's [Pair] for FeedManager storage.
class Pair<T1, T2> {
  Pair(this.first, this.second);

  final T1 first;
  final T2 second;
}
