/// Route paths for the app.
/// Uses DP-1 terminology: Channel, Playlist, Work.
abstract class Routes {
  /// Home route path.
  static const home = '/';

  /// Channels list route path.
  static const channels = '/channels';

  /// All channels route path.
  static const allChannels = '/channels/all';

  /// Playlists list route path.
  static const playlists = '/playlists';

  /// All playlists route path.
  static const allPlaylists = '/playlists/all';

  /// Works list route path.
  static const works = '/works';

  /// FF1 test route path (for development/testing).
  static const ff1Test = '/ff1-test';

  /// Connected devices route path.
  static const connectedDevices = '/connected-devices';

  /// Scan WiFi networks route path (step 1-3 of WiFi connection).
  static const scanWifiNetworks = '/scan-wifi-networks';

  /// Enter WiFi password route path (step 4-6 of WiFi connection).
  static const enterWifiPassword = '/enter-wifi-password';
}

/// Named routes for type-safe navigation.
abstract class RouteNames {
  /// Home route name.
  static const home = 'home';

  /// Channels list route name.
  static const channels = 'channels';

  /// All channels route name.
  static const allChannels = 'all-channels';

  /// Channel detail route name.
  static const channelDetail = 'channel-detail';

  /// Playlists list route name.
  static const playlists = 'playlists';

  /// All playlists route name.
  static const allPlaylists = 'all-playlists';

  /// Playlist detail route name.
  static const playlistDetail = 'playlist-detail';

  /// Works list route name.
  static const works = 'works';

  /// Work detail route name.
  static const workDetail = 'work-detail';

  /// FF1 test route name (for development/testing).
  static const ff1Test = 'ff1-test';

  /// Connected devices route name.
  static const connectedDevices = 'connected-devices';

  /// Scan WiFi networks route name (step 1-3 of WiFi connection).
  static const scanWifiNetworks = 'scan-wifi-networks';

  /// Enter WiFi password route name (step 4-6 of WiFi connection).
  static const enterWifiPassword = 'enter-wifi-password';
}
