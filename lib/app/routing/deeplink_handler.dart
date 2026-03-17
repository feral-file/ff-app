import 'dart:async';

import 'package:app/app/routing/routes.dart';
import 'package:app/domain/constants/deeplink_constants.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Source of a deeplink event.
enum DeeplinkSource {
  /// Deeplink from app startup initial URI.
  initialLink,

  /// Deeplink emitted from app link stream while app is running.
  appLink,

  /// Deeplink from QR scan flow.
  scan,
}

/// Supported deeplink types.
enum DeeplinkType {
  /// Deeplink to FF1 device connection flow.
  deviceConnect,

  /// Deeplink that maps to an app route handled by go_router.
  appRoute,

  /// Unsupported deeplink.
  unknown,
}

/// Navigation target resolved from deeplink source + context.
enum DeeplinkTargetRoute {
  /// Start setup route for FF1 onboarding/setup flow.
  startSetupFf1,

  /// Direct connect route for FF1 connection flow.
  connectFF1,
}

/// Action consumed by app shell for navigation.
class DeeplinkNavigationAction {
  /// Constructor
  const DeeplinkNavigationAction({
    required this.link,
    required this.source,
    required this.type,
    this.location,
  });

  /// The deeplink link.
  final String link;

  /// The source of the deeplink.
  final DeeplinkSource source;

  /// The type of the deeplink.
  final DeeplinkType type;

  /// Resolved go_router location when [type] is [DeeplinkType.appRoute].
  final String? location;
}

/// Normalizes a deeplink by trimming and decoding percent-encoded separators.
String normalizeDeeplink(String rawLink) {
  return Uri.decodeFull(rawLink.trim());
}

/// Classifies deeplink type from configured prefixes.
DeeplinkType classifyDeeplink(String link) {
  if (deviceConnectDeepLinks.any(link.startsWith)) {
    return DeeplinkType.deviceConnect;
  }
  if (resolveAppLocationFromDeeplink(link) != null) {
    return DeeplinkType.appRoute;
  }
  return DeeplinkType.unknown;
}

/// Resolves an app deeplink URI to a go_router location.
String? resolveAppLocationFromDeeplink(String rawLink) {
  final link = normalizeDeeplink(rawLink);
  final uri = Uri.tryParse(link);
  if (uri == null) {
    return null;
  }

  String? location;
  if (uri.scheme == 'feralfile') {
    final host = uri.host.trim();
    if (host.isEmpty) {
      return null;
    }
    location = '/$host${uri.path}';
  } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      appDeeplinkHosts.contains(uri.host)) {
    location = uri.path.isEmpty ? '/' : uri.path;
  } else {
    return null;
  }

  final canonicalLocation = _normalizePlaylistsLocation(location) ??
      _normalizeChannelsLocation(location) ??
      _normalizeWorksLocation(location);
  return canonicalLocation;
}

String? _normalizePlaylistsLocation(String location) {
  if (location == Routes.playlists || location == '${Routes.playlists}/') {
    return Routes.playlists;
  }
  if (location.startsWith('${Routes.playlists}/')) {
    final playlistId = location.substring('${Routes.playlists}/'.length).trim();
    if (playlistId.isEmpty || playlistId.contains('/')) {
      return null;
    }
    return '${Routes.playlists}/$playlistId';
  }
  return null;
}

String? _normalizeChannelsLocation(String location) {
  if (location == Routes.channels || location == '${Routes.channels}/') {
    return Routes.channels;
  }
  if (location == Routes.allChannels) {
    return Routes.allChannels;
  }
  if (location.startsWith('${Routes.channels}/')) {
    final channelId = location.substring('${Routes.channels}/'.length).trim();
    if (channelId.isEmpty || channelId.contains('/')) {
      return null;
    }
    return '${Routes.channels}/$channelId';
  }
  return null;
}

String? _normalizeWorksLocation(String location) {
  if (location == Routes.works || location == '${Routes.works}/') {
    return Routes.works;
  }
  if (location.startsWith('${Routes.works}/')) {
    final workId = location.substring('${Routes.works}/'.length).trim();
    if (workId.isEmpty || workId.contains('/')) {
      return null;
    }
    return '${Routes.works}/$workId';
  }
  // Alias: /items/:id maps to /works/:id
  const itemsPath = '/items';
  if (location.startsWith('$itemsPath/')) {
    final workId = location.substring('$itemsPath/'.length).trim();
    if (workId.isEmpty || workId.contains('/')) {
      return null;
    }
    return '${Routes.works}/$workId';
  }
  return null;
}

/// Abstraction over app_links for testability.
abstract class DeeplinkLinkSource {
  /// Gets the initial link.
  Future<Uri?> getInitialLink();

  /// Gets the link stream.
  Stream<Uri> get linkStream;

  /// Releases resources. No-op by default.
  Future<void> dispose() async {}
}

/// App links deeplink source.
///
/// Merges two URI streams into a single [linkStream]:
/// 1. `app_links.uriLinkStream` — covers custom URL schemes and Android
///    intents.
/// 2. A native MethodChannel (`com.feralfile.app/universal_links`) — captures
///    Universal Links delivered via iOS `scene(_:continue:)` directly from
///    `SceneDelegate.swift`, bypassing the `app_links` initial-link buffer that
///    causes a one-cycle navigation delay on background resume.
class AppLinksDeeplinkSource implements DeeplinkLinkSource {
  /// Constructor — sets up the merged stream immediately.
  AppLinksDeeplinkSource() : _appLinks = AppLinks() {
    _controller = StreamController<Uri>.broadcast();

    // Feed from app_links (custom schemes + non-iOS universal links).
    _appLinksSubscription = _appLinks.uriLinkStream.listen(
      _controller.add,
      onError: _controller.addError,
    );

    // Feed from the native iOS SceneDelegate channel.
    _nativeLinkChannel.setMethodCallHandler(_onNativeUniversalLink);
  }

  static const _nativeLinkChannel = MethodChannel(
    'com.feralfile.app/universal_links',
  );

  final AppLinks _appLinks;
  late final StreamController<Uri> _controller;
  StreamSubscription<Uri>? _appLinksSubscription;

  Future<void> _onNativeUniversalLink(MethodCall call) async {
    if (call.method != 'onUniversalLink') return;
    final urlString = call.arguments as String?;
    if (urlString == null) return;
    final uri = Uri.tryParse(urlString);
    if (uri != null && !_controller.isClosed) {
      _controller.add(uri);
    }
  }

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get linkStream => _controller.stream;

  @override
  Future<void> dispose() async {
    await _appLinksSubscription?.cancel();
    _nativeLinkChannel.setMethodCallHandler(null);
    await _controller.close();
  }
}

/// Riverpod-injected link source.
final deeplinkLinkSourceProvider = Provider<DeeplinkLinkSource>((ref) {
  final source = AppLinksDeeplinkSource();
  ref.onDispose(() => unawaited(source.dispose()));
  return source;
});

/// Provider for deeplink coordinator.
final deeplinkHandlerProvider = Provider<DeeplinkHandler>((ref) {
  final handler = DeeplinkHandler(
    linkSource: ref.watch(deeplinkLinkSourceProvider),
  );
  ref.onDispose(() {
    unawaited(handler.dispose());
  });
  return handler;
});

/// Stream of deeplink navigation actions.
final deeplinkActionsProvider = StreamProvider<DeeplinkNavigationAction>((ref) {
  final handler = ref.watch(deeplinkHandlerProvider);
  return handler.actions;
});

/// Time window for deduplicating the same link delivered multiple times.
/// On cold start or when link.feralfile.com redirects, app_links can deliver
/// the same URI via both getInitialLink and uriLinkStream, or uriLinkStream
/// can fire twice (e.g. Android onNewIntent with redirects).
const Duration _deeplinkDedupWindow = Duration(seconds: 2);

/// Coordinates deeplink ingestion and emits typed navigation actions.
class DeeplinkHandler {
  /// Constructor
  DeeplinkHandler({
    required DeeplinkLinkSource linkSource,
  }) : _linkSource = linkSource;

  final DeeplinkLinkSource _linkSource;
  final Map<String, bool> _handlingLinks = <String, bool>{};
  final Map<String, DateTime> _recentlyProcessedLinks = <String, DateTime>{};
  final StreamController<DeeplinkNavigationAction> _actionsController =
      StreamController<DeeplinkNavigationAction>.broadcast();

  StreamSubscription<Uri>? _linkSubscription;
  bool _isStarted = false;

  /// The stream of deeplink navigation actions.
  Stream<DeeplinkNavigationAction> get actions => _actionsController.stream;

  /// Whether the handler is handling a deep link.
  bool get isHandlingDeepLink => _handlingLinks.isNotEmpty;

  /// Starts initial-link + app-link ingestion exactly once.
  Future<void> start() async {
    if (_isStarted) {
      return;
    }
    _isStarted = true;

    final initialLink = await _linkSource.getInitialLink();
    if (initialLink != null) {
      await handleDeeplink(
        initialLink.toString(),
        isFromAppLink: true,
      );
    }

    _linkSubscription = _linkSource.linkStream.listen((uri) {
      unawaited(
        handleDeeplink(
          uri.toString(),
          isFromAppLink: true,
        ),
      );
    });
  }

  /// Safety-net check for [DeeplinkLinkSource.getInitialLink] on app resume.
  ///
  /// The primary delivery path for iOS Universal Links on background resume is
  /// the native `SceneDelegate.scene(_:continue:)` override, which forwards
  /// the URL directly into [linkStream] via a MethodChannel. This fallback
  /// handles edge cases where the MethodChannel fires before [linkStream]'s
  /// subscription is active, or on non-iOS platforms. The dedup window in
  /// [_processLink] prevents double-navigation if both paths deliver the link.
  Future<void> checkForResumeLink() async {
    final link = await _linkSource.getInitialLink();
    if (link != null) {
      await handleDeeplink(link.toString(), isFromAppLink: true);
    }
  }

  /// Handles deeplink with sample-compatible options.
  Future<DeeplinkNavigationAction?> handleDeeplink(
    String? rawLink, {
    Duration delay = Duration.zero,
    FutureOr<void> Function()? onFinished,
    bool isFromAppLink = false,
  }) async {
    final source = isFromAppLink ? DeeplinkSource.appLink : DeeplinkSource.scan;
    return _processLink(
      rawLink,
      source: source,
      onFinished: onFinished,
      delay: delay,
    );
  }

  /// Handles deeplink from any source (app links or QR scan).
  Future<DeeplinkNavigationAction?> handleRawLink(
    String? rawLink, {
    required DeeplinkSource source,
    FutureOr<void> Function()? onFinished,
  }) async {
    return _processLink(
      rawLink,
      source: source,
      onFinished: onFinished,
    );
  }

  Future<DeeplinkNavigationAction?> _processLink(
    String? rawLink, {
    required DeeplinkSource source,
    FutureOr<void> Function()? onFinished,
    Duration delay = Duration.zero,
  }) async {
    if (rawLink == null || rawLink.isEmpty || rawLink == 'autonomy://') {
      return null;
    }

    final link = normalizeDeeplink(rawLink);
    if (_handlingLinks[link] ?? false) {
      return null;
    }
    _handlingLinks[link] = true;

    try {
      await Future<void>.delayed(delay);

      final type = classifyDeeplink(link);
      if (type == DeeplinkType.unknown) {
        return null;
      }

      _pruneExpiredDedupEntries();
      final lastProcessed = _recentlyProcessedLinks[link];
      if (lastProcessed != null &&
          DateTime.now().difference(lastProcessed) < _deeplinkDedupWindow) {
        return null;
      }

      final action = DeeplinkNavigationAction(
        link: link,
        source: source,
        type: type,
        location: type == DeeplinkType.appRoute
            ? resolveAppLocationFromDeeplink(link)
            : null,
      );
      if (!_actionsController.isClosed) {
        _actionsController.add(action);
        _recentlyProcessedLinks[link] = DateTime.now();
      }
      return action;
    } finally {
      _handlingLinks.remove(link);
      await onFinished?.call();
    }
  }

  void _pruneExpiredDedupEntries() {
    final now = DateTime.now();
    _recentlyProcessedLinks.removeWhere(
      (_, time) => now.difference(time) >= _deeplinkDedupWindow,
    );
  }

  /// Disposes the handler and its link source.
  Future<void> dispose() async {
    await _linkSubscription?.cancel();
    await _actionsController.close();
    await _linkSource.dispose();
  }
}
