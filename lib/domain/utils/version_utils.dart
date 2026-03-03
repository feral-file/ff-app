/// Compares two version strings.
///
/// Supports formats like "1.0.5" and "1.0.5(123)" (build number in parentheses).
/// Returns:
/// - positive if [version1] > [version2]
/// - negative if [version1] < [version2]
/// - 0 if equal
int compareVersion(String version1, String version2) {
  List<int> parseVersion(String version) {
    final regex = RegExp(r'^([\d.]+)(?:\((\d+)\))?$');
    final match = regex.firstMatch(version.trim());

    if (match == null) return [];

    final base = match.group(1)!;
    final build = match.group(2);

    final baseParts = base.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    if (build != null) {
      baseParts.add(int.tryParse(build) ?? 0);
    }
    return baseParts;
  }

  final ver1 = parseVersion(version1);
  final ver2 = parseVersion(version2);

  final maxLength = ver1.length > ver2.length ? ver1.length : ver2.length;

  for (var i = 0; i < maxLength; i++) {
    final v1 = i < ver1.length ? ver1[i] : 0;
    final v2 = i < ver2.length ? ver2[i] : 0;
    final diff = v1 - v2;
    if (diff != 0) return diff;
  }

  return 0;
}
