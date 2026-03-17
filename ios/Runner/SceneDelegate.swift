import Flutter
import UIKit

/// Custom scene delegate that captures Universal Links delivered via
/// `scene(_:continue:)` and forwards them to Dart through a dedicated
/// MethodChannel.
///
/// `FlutterSceneDelegate` (the base class) handles all Flutter lifecycle and
/// plugin-registry forwarding. We only add `scene(_:continue:)` interception
/// to work around the `app_links` limitation where Universal Links on
/// background resume are stored in the initial-link buffer rather than emitted
/// to `uriLinkStream`, causing navigation to fire one lifecycle cycle late.
///
/// The channel name must match `AppLinksDeeplinkSource._nativeLinkChannelName`
/// in `lib/app/routing/deeplink_handler.dart`.
class SceneDelegate: FlutterSceneDelegate {

  private static let channelName = "com.feralfile.app/universal_links"

  override func scene(
    _ scene: UIScene,
    continue userActivity: NSUserActivity
  ) {
    // Let FlutterSceneDelegate run first so the plugin registry (including
    // app_links) handles its own bookkeeping before we forward the URL.
    super.scene(scene, continue: userActivity)

    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
      let url = userActivity.webpageURL
    else { return }

    forwardLinkToDart(url: url, scene: scene)
  }

  private func forwardLinkToDart(url: URL, scene: UIScene) {
    guard let windowScene = scene as? UIWindowScene,
      let window = windowScene.windows.first,
      let flutterVC = window.rootViewController as? FlutterViewController
    else { return }

    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: flutterVC.binaryMessenger
    )
    channel.invokeMethod("onUniversalLink", arguments: url.absoluteString)
  }
}
