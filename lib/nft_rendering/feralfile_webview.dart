// ignore_for_file: discarded_futures, document_ignores

import 'dart:async';

import 'package:app/nft_rendering/nft_loading_widget.dart';
import 'package:app/nft_rendering/webview_controller_ext.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

final _log = Logger('FeralFileWebview');

/// WebView wrapper used for NFT media rendering.
class FeralFileWebview extends StatefulWidget {
  /// Creates a webview with loading and lifecycle-safe callbacks.
  const FeralFileWebview({
    required this.uri,
    super.key,
    this.overriddenHtml,
    this.isMute = false,
    this.backgroundColor = Colors.transparent,
    this.userAgent,
    this.onLoaded,
    this.onStarted,
    this.onResourceError,
    this.onHttpError,
    this.onConsoleMessage,
  });

  /// Initial URL to load when `overriddenHtml` is null.
  final Uri uri;

  /// Optional inline HTML string to render instead of loading [uri].
  final String? overriddenHtml;

  /// Whether to mute media after the page finishes loading.
  final bool isMute;

  /// WebView background color and loading placeholder background.
  final Color backgroundColor;

  /// Optional web user-agent override.
  final String? userAgent;

  /// Called when a page finished loading.
  final void Function(WebViewController webViewController)? onLoaded;

  /// Called when page loading starts.
  final void Function(WebViewController webViewController)? onStarted;

  /// Called when the webview reports a resource loading error.
  final void Function(
    WebViewController webViewController,
    WebResourceError error,
  )?
  onResourceError;

  /// Called when the webview reports an HTTP response error.
  final void Function(
    WebViewController webViewController,
    HttpResponseError error,
  )?
  onHttpError;

  /// Called when JavaScript writes a console message.
  final void Function(
    WebViewController webViewController,
    JavaScriptConsoleMessage consoleMessage,
  )?
  onConsoleMessage;

  @override
  State<FeralFileWebview> createState() => _FeralFileWebviewState();
}

class _FeralFileWebviewState extends State<FeralFileWebview> {
  late WebViewController _webViewController;
  double _loadingProgress = 0;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _webViewController = _getWebViewController();
    _webViewController.load(
      widget.uri,
      widget.overriddenHtml,
    );
  }

  Widget _buildLoadingWidget() {
    return ColoredBox(
      color: widget.backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingWidget(
              backgroundColor: widget.backgroundColor,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      AnimatedOpacity(
        opacity: _loadingProgress > 0.0 ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: WebViewWidget(
          key: Key(widget.uri.toString()),
          controller: _webViewController,
          gestureRecognizers: const {
            Factory<OneSequenceGestureRecognizer>(
              EagerGestureRecognizer.new,
            ),
          },
        ),
      ),
      Positioned.fill(
        child: IgnorePointer(
          ignoring: _loadingProgress >= 1,
          child: AnimatedOpacity(
            opacity: _loadingProgress < 1 ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: _buildLoadingWidget(),
          ),
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _isDisposed = true;
    // webViewController disposes itself.
    _webViewController.onDispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FeralFileWebview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri ||
        oldWidget.overriddenHtml != widget.overriddenHtml) {
      _webViewController.load(
        widget.uri,
        widget.overriddenHtml,
      );
    }
  }

  WebViewController _getWebViewController() {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    final webViewController = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (request) {
        // Handle permission requests here
      },
    );
    webViewController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.backgroundColor)
      ..enableZoom(false)
      ..setUserAgent(widget.userAgent)
      ..setOnConsoleMessage((message) {
        _log.info('Console: ${message.message}');
        widget.onConsoleMessage?.call(webViewController, message);
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            _setLoadingProgress(progress / 100);
          },
          onPageStarted: (url) async {
            if (_isDisposed || !mounted) return;
            _log.info('Page started loading: $url');
            _setLoadingProgress(0);
            unawaited(webViewController.skipPrint());
            widget.onStarted?.call(webViewController);
          },
          onPageFinished: (url) async {
            if (_isDisposed || !mounted) return;
            _setLoadingProgress(1);
            widget.onLoaded?.call(webViewController);
            if (widget.isMute) {
              await webViewController.mute();
            }
            _log.info('Page finished loading: $url');
          },
          onWebResourceError: (error) {
            _log.info('Error: ${error.description}');
            widget.onResourceError?.call(webViewController, error);
          },
          onHttpError: (error) {
            _log.info('HttpError: $error');
            widget.onHttpError?.call(webViewController, error);
          },
          onNavigationRequest: (request) async {
            _log.info('Navigation request to: ${request.url}');
            return NavigationDecision.navigate;
          },
          onUrlChange: (url) {
            _log.info('Url changed: $url');
          },
        ),
      );
    if (webViewController.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(kDebugMode);
      unawaited(
        (webViewController.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false),
      );
    }
    return webViewController;
  }

  void _setLoadingProgress(double value) {
    if (_isDisposed || !mounted) {
      return;
    }
    setState(() {
      _loadingProgress = value;
    });
  }
}
