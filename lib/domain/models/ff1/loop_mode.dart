/// Playback loop mode for FF1.
enum LoopMode {
  /// Loop the entire playlist from the beginning when it ends.
  playlist,

  /// Loop the currently displayed artwork indefinitely.
  one
  ;

  /// Wire format value sent to the device.
  String get wireValue {
    switch (this) {
      case LoopMode.playlist:
        return 'playlist';
      case LoopMode.one:
        return 'one';
    }
  }

  /// Parse from wire format value.
  static LoopMode fromString(String value) {
    for (final mode in LoopMode.values) {
      if (mode.wireValue == value) return mode;
    }
    throw ArgumentError('Unknown LoopMode: $value');
  }

  /// Returns the next mode in the cycle: playlist → one → playlist.
  LoopMode get next {
    switch (this) {
      case LoopMode.playlist:
        return LoopMode.one;
      case LoopMode.one:
        return LoopMode.playlist;
    }
  }
}
