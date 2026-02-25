import 'dart:async';

import 'package:app/nft_rendering/feralfile_webview.dart';
import 'package:app/nft_rendering/nft_loading_widget.dart';
import 'package:app/nft_rendering/nft_rendering_widget.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';

final _log = Logger('GifNFTRenderingWidget');

class GifNFTRenderingWidget extends NFTRenderingWidget {

  const GifNFTRenderingWidget({
    required this.previewURL,
    super.key,
    this.noPreviewUrlWidget,
    this.loadingWidget,
    this.errorWidget,
    this.onLoaded,
  });
  final String previewURL;
  final Widget? noPreviewUrlWidget;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final VoidCallback? onLoaded;

  @override
  State<GifNFTRenderingWidget> createState() => _GifNFTRenderingWidgetState();
}

class _GifNFTRenderingWidgetState extends State<GifNFTRenderingWidget> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.previewURL.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isLoading = false;
        });
      });
    }
  }

  Widget _buildGifWidget() {
    if (widget.previewURL.isEmpty) {
      return widget.noPreviewUrlWidget ?? const SizedBox.shrink();
    }

    return Image.network(widget.previewURL,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            _onImageLoaded();
            return child;
          }
          return widget.loadingWidget ?? const LoadingWidget();
        },
        errorBuilder: (context, error, stackTrace) => Center(
              child: _fallbackWebview(),
            ));
  }

  Widget _fallbackWebview() {
    final previewURL = widget.previewURL;
    return Center(
      child: FeralFileWebview(
        key: Key('FeralFileWebview_$previewURL'),
        uri: Uri.parse(previewURL),
        onResourceError: (controller, error) {
          unawaited(Sentry.captureException(
            error,
            stackTrace: StackTrace.current,
            hint: Hint.withMap({
              'url': previewURL,
            }),
          ));
          _log.info('Error when load gif with webview: $error on $previewURL');
        },
      ),
    );
  }

  void _onImageLoaded() {
    if (_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _isLoading = false;
        });
      });
    }
    widget.onLoaded?.call();
  }

  @override
  Widget build(BuildContext context) => _buildGifWidget();
}
