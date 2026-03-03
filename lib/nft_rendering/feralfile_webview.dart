// ignore_for_file: discarded_futures

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

class FeralFileWebview extends StatefulWidget {
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
  final Uri uri;
  final String? overriddenHtml;
  final bool isMute;
  final Color backgroundColor;
  final String? userAgent;
  final void Function(WebViewController webViewController)? onLoaded;
  final void Function(WebViewController webViewController)? onStarted;
  final void Function(
    WebViewController webViewController,
    WebResourceError error,
  )?
  onResourceError;
  final void Function(
    WebViewController webViewController,
    HttpResponseError error,
  )?
  onHttpError;
  final void Function(
    WebViewController webViewController,
    JavaScriptConsoleMessage consoleMessage,
  )?
  onConsoleMessage;

  @override
  State<FeralFileWebview> createState() => FeralFileWebviewState();
}

class FeralFileWebviewState extends State<FeralFileWebview> {
  late WebViewController _webViewController;
  double _loadingProgress = 0;

  @override
  void initState() {
    super.initState();
    _webViewController = getWebViewController();
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
          ignoring: _loadingProgress >= 1.0,
          child: Container(
            child: AnimatedOpacity(
              opacity: _loadingProgress < 1.0 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildLoadingWidget(),
            ),
          ),
        ),
      ),
    ],
  );

  @override
  void dispose() {
    super.dispose();
    // webViewController dispose itself
    _webViewController.onDispose();
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

  WebViewController getWebViewController() {
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
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageStarted: (url) async {
            _log.info('Page started loading: $url');
            setState(() {
              _loadingProgress = 0.0;
            });
            unawaited(webViewController.skipPrint());
            widget.onStarted?.call(webViewController);
          },
          onPageFinished: (url) async {
            setState(() {
              _loadingProgress = 1.0;
            });
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
}
