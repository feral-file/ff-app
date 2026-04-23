import 'package:meta/meta.dart';

/// DP-1 publisher as stored in the local read model (publishers table).
///
/// This is the domain shape for watch-publishers consumers, not a Drift row
/// type.
@immutable
class DP1Publisher {
  /// Creates a [DP1Publisher].
  const DP1Publisher({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Publisher id (indexer / local integer key).
  final int id;

  /// Display name for section headers and lookups.
  final String title;

  /// Creation time from the publishers row.
  final DateTime createdAt;

  /// Last update time from the publishers row.
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DP1Publisher &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(id, title, createdAt, updatedAt);
}
