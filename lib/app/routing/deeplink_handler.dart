import 'dart:async';

import 'package:app/domain/constants/deeplink_constants.dart';
import 'package:app_links/app_links.dart';
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

  if (!_isSupportedAppDeeplinkLocation(location)) {
    return null;
  }

  final query = uri.query;
  if (query.isNotEmpty) {
    return '$location?$query';
  }
  return location;
}

bool _isSupportedAppDeeplinkLocation(String location) {
  return location == '/playlist' ||
      location.startsWith('/playlist/') ||
      location.startsWith('/playlists/');
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

/// Coordinates deeplink ingestion and emits typed navigation actions.
class DeeplinkHandler {
  /// Constructor
  DeeplinkHandler({
    required DeeplinkLinkSource linkSource,
  }) : _linkSource = linkSource;

  final DeeplinkLinkSource _linkSource;
  final Map<String, bool> _handlingLinks = <String, bool>{};
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
      }
      return action;
    } finally {
      _handlingLinks.remove(link);
      await onFinished?.call();
    }
  }

  /// Disposes the handler.
  Future<void> dispose() async {
    await _linkSubscription?.cancel();
    await _actionsController.close();
  }
}
