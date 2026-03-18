import 'dart:async';

import 'package:app/app/routing/routes.dart';
import 'package:app/domain/constants/deeplink_constants.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

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

  final canonicalLocation =
      _normalizePlaylistsLocation(location) ??
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
}

/// App links deeplink source.
class AppLinksDeeplinkSource implements DeeplinkLinkSource {
  /// Constructor
  AppLinksDeeplinkSource() : _appLinks = AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() {
    return _appLinks.getInitialLink();
  }

  @override
  Stream<Uri> get linkStream => _appLinks.uriLinkStream;
}

/// Riverpod-injected link source.
final deeplinkLinkSourceProvider = Provider<DeeplinkLinkSource>((ref) {
  return AppLinksDeeplinkSource();
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

final _log = Logger('DeeplinkHandler');

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

  // Tracks the last URI returned by getInitialLink() that we have already
  // dispatched. On iOS the native initial-link buffer may keep returning the
  // same URI across multiple app-resume cycles; comparing against this field
  // lets us suppress re-processing without relying on a time window (which
  // would fail for resumes longer than _deeplinkDedupWindow).
  String? _lastProcessedInitialLink;

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
      _log.info('initialLink: $initialLink');
      _lastProcessedInitialLink = initialLink.toString();
      await handleDeeplink(
        initialLink.toString(),
        isFromAppLink: true,
      );
    }

    _linkSubscription = _linkSource.linkStream.listen((uri) {
      _log.info('linkStream uri: $uri');
      unawaited(
        handleDeeplink(
          uri.toString(),
          isFromAppLink: true,
        ),
      );
    });
  }

  /// Re-reads [DeeplinkLinkSource.getInitialLink] on app resume.
  ///
  /// On iOS with scene-based lifecycle, when a suspended app is brought to
  /// foreground via a Universal Link, the OS calls `scene(_:continue:)` and
  /// `app_links` stores that link in the same native buffer used for cold
  /// start, rather than emitting it to [linkStream]. Calling this on every
  /// [AppLifecycleState.resumed] event ensures that link is not silently
  /// dropped.
  ///
  /// We compare against [_lastProcessedInitialLink] rather than the time-based
  /// dedup window: the native buffer can keep returning the same URI across
  /// many resume cycles (seconds to minutes apart), so a fixed-duration window
  /// would re-trigger navigation on later resumes.
  Future<void> checkForResumeLink() async {
    final link = await _linkSource.getInitialLink();
    if (link == null) {
      return;
    }
    final linkStr = link.toString();
    if (linkStr == _lastProcessedInitialLink) {
      // Same URI still in native buffer; already dispatched on a prior
      // cold-start or resume. Skip to avoid re-triggering navigation.
      return;
    }
    _lastProcessedInitialLink = linkStr;
    await handleDeeplink(linkStr, isFromAppLink: true);
  }

  /// Handles deeplink with sample-compatible options.
  Future<DeeplinkNavigationAction?> handleDeeplink(
    String? rawLink, {
    Duration delay = Duration.zero,
    FutureOr<void> Function()? onFinished,
    bool isFromAppLink = false,
  }) async {
    final source = isFromAppLink ? DeeplinkSource.appLink : DeeplinkSource.scan;
    // Log scheme/host/path only; query parameters may contain pairing tokens.
    final sanitized = rawLink != null
        ? (Uri.tryParse(rawLink)?.replace(queryParameters: {}).toString() ??
            rawLink)
        : null;
    _log.info('handleDeeplink link: $sanitized, source: $source');
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

  /// Disposes the handler.
  Future<void> dispose() async {
    await _linkSubscription?.cancel();
    await _actionsController.close();
  }
}
