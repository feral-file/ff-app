/// Route paths for the app.
/// Uses DP-1 terminology: Channel, Playlist, Work.
abstract class Routes {
  /// Home route path.
  static const home = '/';

  /// Onboarding route path.
  static const onboarding = '/onboarding';

  /// Onboarding introduce page route path.
  static const onboardingIntroducePage = '/onboarding/introduce';

  /// Onboarding add address page route path.
  static const onboardingAddAddressPage = '/onboarding/add-address';

  /// Onboarding setup FF1 page route path.
  static const onboardingSetupFf1Page = '/onboarding/setup-ff1';

  /// FF1 device picker page route path.
  static const ff1DevicePickerPage = '/ff1-device-picker';

  /// Handle Bluetooth device scan deeplink screen route path.
  static const handleBluetoothDeviceScanDeeplinkPage =
      '/handle-bluetooth-device-scan-deeplink';

  /// Connect FF1 page route path.
  static const connectFF1Page = '/connect-ff1';

  /// Add address input page route path.
  static const addAddressPage = '/add-address';

  /// Add alias page route path.
  static const addAliasPage = '/add-alias';

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

  /// Start setup FF1 route path
  static const startSetupFf1 = '/start-setup-ff1';

  /// Scan WiFi networks route path (step 1-3 of WiFi connection).
  static const scanWifiNetworks = '/scan-wifi-networks';

  /// Enter WiFi password route path (step 4-6 of WiFi connection).
  static const enterWifiPassword = '/enter-wifi-password';

  /// Device configuration route path.
  static const deviceConfiguration = '/device-configuration';

  /// FF1 updating route path.
  static const ff1Updating = '/ff1-updating';

  /// Now displaying (full-screen) route path.
  static const nowDisplaying = '/now-displaying';

  /// Keyboard control (interact) route path.
  static const keyboardControl = '/keyboard-control';

  /// Release notes list route path.
  static const releaseNotes = '/release-notes';

  /// Release note detail route path.
  static const releaseNoteDetail = '/release-notes/detail';

  /// Settings (Account) page route path.
  static const settings = '/settings';

  /// EULA document viewer (child of settings).
  static const settingsEula = '/settings/eula';

  /// Privacy Policy document viewer (child of settings).
  static const settingsPrivacy = '/settings/privacy';
}

/// Named routes for type-safe navigation.
abstract class RouteNames {
  /// Home route name.
  static const home = 'home';

  /// Onboarding route name.
  static const onboarding = 'onboarding';

  /// Onboarding introduce page route name.
  static const onboardingIntroduce = 'onboarding-introduce';

  /// Onboarding add address page route name.
  static const onboardingAddAddress = 'onboarding-add-address';

  /// Onboarding setup FF1 page route name.
  static const onboardingSetupFf1 = 'onboarding-setup-ff1';

  /// FF1 device picker page route name.
  static const ff1DevicePicker = 'ff1-device-picker';

  /// Handle Bluetooth device scan deeplink screen route name.
  static const handleBluetoothDeviceScanDeeplink =
      'handle-bluetooth-device-scan-deeplink';

  /// Connect FF1 page route name.
  static const connectFF1 = 'connect-ff1';

  /// Add address input page route name.
  static const addAddress = 'add-address';

  /// Add alias page route name.
  static const addAlias = 'add-alias';

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

  /// Start setup FF1 route name.
  static const startSetupFf1 = 'start-setup-ff1';

  /// Scan WiFi networks route name (step 1-3 of WiFi connection).
  static const scanWifiNetworks = 'scan-wifi-networks';

  /// Enter WiFi password route name (step 4-6 of WiFi connection).
  static const enterWifiPassword = 'enter-wifi-password';

  /// Device configuration route name.
  static const deviceConfiguration = 'device-configuration';

  /// FF1 updating route name.
  static const ff1Updating = 'ff1-updating';

  /// Now displaying route name.
  static const nowDisplaying = 'now-displaying';

  /// Keyboard control route name.
  static const keyboardControl = 'keyboard-control';

  /// Release notes list route name.
  static const releaseNotes = 'release-notes';

  /// Release note detail route name.
  static const releaseNoteDetail = 'release-note-detail';

  /// Settings (Account) route name.
  static const settings = 'settings';

  /// EULA document viewer route name.
  static const settingsEula = 'settings-eula';

  /// Privacy Policy document viewer route name.
  static const settingsPrivacy = 'settings-privacy';
}
