/// Playback loop mode for FF1.
///
/// Wire contract: `none` | `playlist` | `one`. FF1 stops advancing after the
/// last slot when [none]; wraps to the first slot for [playlist]; holds the
/// current slot for [one].
enum LoopMode {
  /// Do not loop: after the last slot, playback does not advance.
  none,

  /// Loop the entire playlist from the beginning when it ends.
  playlist,

  /// Loop the currently displayed artwork indefinitely.
  one
  ;

  /// Wire format value sent to the device.
  String get wireValue {
    switch (this) {
      case LoopMode.none:
        return 'none';
      case LoopMode.playlist:
        return 'playlist';
      case LoopMode.one:
        return 'one';
    }
  }

  /// Parse known wire values; returns null for null, empty, or unknown.
  static LoopMode? tryParse(Object? value) {
    if (value is! String || value.isEmpty) return null;
    for (final mode in LoopMode.values) {
      if (mode.wireValue == value) return mode;
    }
    return null;
  }

  /// Parse from wire format value.
  static LoopMode fromString(String value) {
    final parsed = tryParse(value);
    if (parsed != null) return parsed;
    throw ArgumentError('Unknown LoopMode: $value');
  }

  /// UI / command cycle: off → repeat all → repeat one → off.
  LoopMode get next {
    switch (this) {
      case LoopMode.none:
        return LoopMode.playlist;
      case LoopMode.playlist:
        return LoopMode.one;
      case LoopMode.one:
        return LoopMode.none;
    }
  }
}
