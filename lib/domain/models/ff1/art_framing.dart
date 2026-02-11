/// Art framing mode for FF1 display.
enum ArtFraming {
  fitToScreen,
  cropToFill;

  int get value {
    switch (this) {
      case ArtFraming.fitToScreen:
        return 0;
      case ArtFraming.cropToFill:
        return 1;
    }
  }

  String get name {
    switch (this) {
      case ArtFraming.fitToScreen:
        return 'fit';
      case ArtFraming.cropToFill:
        return 'fill';
    }
  }

  static ArtFraming fromString(String framing) {
    switch (framing) {
      case 'fit':
        return ArtFraming.fitToScreen;
      case 'fill':
        return ArtFraming.cropToFill;
      default:
        throw ArgumentError('Unknown framing: $framing');
    }
  }

  static ArtFraming fromValue(int value) {
    switch (value) {
      case 0:
        return ArtFraming.fitToScreen;
      case 1:
        return ArtFraming.cropToFill;
      default:
        throw ArgumentError('Unknown value: $value');
    }
  }
}
