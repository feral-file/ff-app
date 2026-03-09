/// Returns true when a tab should trigger a fresh load.
///
/// We only load when the tab is idle and has no cached items, or when
/// it previously failed and needs a retry path.
bool shouldLoadTabData({
  required bool isLoading,
  required bool hasCachedItems,
  required bool hasError,
}) {
  if (isLoading) {
    return false;
  }
  if (hasError) {
    return true;
  }
  return !hasCachedItems;
}
