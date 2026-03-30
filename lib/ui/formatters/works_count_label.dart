/// English UI fragment for a numeric [count] of domain objects named "work"
/// (singular/plural), e.g. playlist headers and indexing status lines.
String formatWorksCountLabel(int count) {
  return count == 1 ? '1 work' : '$count works';
}
