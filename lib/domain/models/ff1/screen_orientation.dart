/// Screen orientation for FF1 device display.
enum ScreenOrientation {
  landscape,
  landscapeReverse,
  portrait,
  portraitReverse;

  String get name {
    switch (this) {
      case ScreenOrientation.landscape:
        return 'landscape';
      case ScreenOrientation.landscapeReverse:
        return 'landscapeReverse';
      case ScreenOrientation.portrait:
        return 'portrait';
      case ScreenOrientation.portraitReverse:
        return 'portraitReverse';
    }
  }

  static ScreenOrientation fromString(String value) {
    switch (value) {
      case 'landscape':
      case 'normal':
        return ScreenOrientation.landscape;
      case 'landscapeReverse':
      case 'inverted':
        return ScreenOrientation.landscapeReverse;
      case 'portrait':
      case 'left':
        return ScreenOrientation.portrait;
      case 'portraitReverse':
      case 'right':
        return ScreenOrientation.portraitReverse;
      default:
        throw ArgumentError('Invalid screen orientation: $value');
    }
  }
}
