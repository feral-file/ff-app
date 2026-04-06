/// Errors from FFP DDC relayer commands (distinct from FF1 audio commands).
library;

/// Thrown when controld reports an operation is not supported for this panel.
class FfpDdcUnsupportedException implements Exception {
  /// Creates an unsupported exception.
  FfpDdcUnsupportedException(this.message);

  /// Human-readable reason (often from device or relayer).
  final String message;

  @override
  String toString() => 'FfpDdcUnsupportedException: $message';
}

/// Thrown when an FFP DDC command fails for a reason other than unsupported.
class FfpDdcCommandException implements Exception {
  /// Creates a command exception.
  FfpDdcCommandException(this.message);

  final String message;

  @override
  String toString() => 'FfpDdcCommandException: $message';
}
