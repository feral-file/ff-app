import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for handling deep links.
/// Listens to incoming app links and exposes them as a stream.
final deeplinkHandlerProvider = Provider<DeeplinkHandler>((ref) {
  return DeeplinkHandler();
});

/// Handles deep link events from app_links.
/// External events (deep links) funnel through Riverpod for global access.
class DeeplinkHandler {
  final _appLinks = AppLinks();

  /// Get the initial link that opened the app (if any).
  Future<Uri?> getInitialLink() async {
    return _appLinks.getInitialLink();
  }

  /// Stream of incoming deep links while the app is running.
  Stream<Uri> get linkStream => _appLinks.uriLinkStream;
}

/// Provider that exposes the stream of deep links.
final deeplinkStreamProvider = StreamProvider<Uri>((ref) {
  final handler = ref.watch(deeplinkHandlerProvider);
  return handler.linkStream;
});
