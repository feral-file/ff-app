import 'package:flutter/widgets.dart';

/// Semantic keys used by gold-path Patrol automation.
abstract final class GoldPathPatrolKeys {
  /// Home tab button that switches to the Playlists surface.
  static const playlistsTab = ValueKey<String>('gold_path.home.tab.playlists');

  /// Home tab button that switches to the Channels surface.
  static const channelsTab = ValueKey<String>('gold_path.home.tab.channels');

  /// Curated section header inside the Channels tab.
  static const curatedChannelsSection = ValueKey<String>(
    'gold_path.channels.section.curated',
  );

  /// Primary FF1 display button rendered in work and playlist details.
  static const ffDisplayButton = ValueKey<String>(
    'gold_path.ff1.display_button',
  );

  /// Tooltip play button shown the first time the FF1 display affordance
  /// appears.
  static const ffDisplayTooltipButton = ValueKey<String>(
    'gold_path.ff1.display_tooltip_button',
  );

  /// Global Now Displaying overlay card.
  static const nowDisplayingBar = ValueKey<String>(
    'gold_path.now_displaying.bar',
  );

  /// Introduce onboarding action that advances to add-address step.
  static const onboardingIntroduceNext = ValueKey<String>(
    'gold_path.onboarding.introduce.next',
  );

  /// Add-address onboarding action that opens add-address flow.
  static const onboardingAddAddressPrimary = ValueKey<String>(
    'gold_path.onboarding.add_address.primary',
  );

  /// Add-address onboarding action that advances (Skip for now / Next).
  static const onboardingAddAddressSecondary = ValueKey<String>(
    'gold_path.onboarding.add_address.secondary',
  );

  /// Setup-FF1 onboarding action that opens FF1 setup flow.
  static const onboardingSetupFf1Primary = ValueKey<String>(
    'gold_path.onboarding.setup_ff1.primary',
  );

  /// Setup-FF1 onboarding action that finishes onboarding.
  static const onboardingSetupFf1Secondary = ValueKey<String>(
    'gold_path.onboarding.setup_ff1.secondary',
  );

  /// Add-address screen action to submit an address.
  static const onboardingAddAddressSubmit = ValueKey<String>(
    'gold_path.onboarding.add_address.submit',
  );

  /// Connect FF1 page action to retry connection.
  static const connectFF1Retry = ValueKey<String>(
    'gold_path.ff1_setup.connect_ff1.retry',
  );

  /// Connect FF1 page action to cancel connection.
  static const connectFF1Cancel = ValueKey<String>(
    'gold_path.ff1_setup.connect_ff1.cancel',
  );

  /// WiFi network row in scan results (scoped to network SSID).
  static ValueKey<String> wifiNetworkRow(String ssid) {
    return ValueKey<String>('gold_path.ff1_setup.wifi.network.$ssid');
  }

  /// WiFi scan retry action.
  static const wifiScanRetry = ValueKey<String>(
    'gold_path.ff1_setup.wifi.scan_retry',
  );

  /// WiFi password submit action.
  static const wifiPasswordSubmit = ValueKey<String>(
    'gold_path.ff1_setup.wifi.password_submit',
  );

  /// Stable channel row key for Curated channel carousels.
  static ValueKey<String> channelRow(String channelId) {
    return ValueKey<String>('gold_path.channels.row.$channelId');
  }

  /// Stable work item key scoped to a specific channel carousel row.
  static ValueKey<String> channelWork({
    required String channelId,
    required String workId,
  }) {
    return ValueKey<String>('gold_path.channels.row.$channelId.work.$workId');
  }

  /// Stable work thumbnail key for detail or shelf reuse when needed.
  static ValueKey<String> workThumbnail(String workId) {
    return ValueKey<String>('gold_path.work.thumbnail.$workId');
  }
}
