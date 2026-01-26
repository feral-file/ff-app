/// Route paths for the app.
/// Uses DP-1 terminology: Channel, Playlist, Work.
abstract class Routes {
  /// Home route path.
  static const home = '/';

  /// Channels list route path.
  static const channels = '/channels';

  /// Playlists list route path.
  static const playlists = '/playlists';

  /// Works list route path.
  static const works = '/works';
}

/// Named routes for type-safe navigation.
abstract class RouteNames {
  /// Home route name.
  static const home = 'home';

  /// Channels list route name.
  static const channels = 'channels';

  /// Channel detail route name.
  static const channelDetail = 'channel-detail';

  /// Playlists list route name.
  static const playlists = 'playlists';

  /// Playlist detail route name.
  static const playlistDetail = 'playlist-detail';

  /// Works list route name.
  static const works = 'works';

  /// Work detail route name.
  static const workDetail = 'work-detail';
}
