import 'package:app/nft_rendering/nft_rendering_widget.dart';
import 'package:http/http.dart' as http;

/// Resolves HTTP Content-Type header to a rendering type string for work preview.
/// Uses HTTP HEAD on the given URL; on error or null returns [RenderingType.webview].
Future<String> contentType(String link) async {
  var renderingType = RenderingType.webview;
  final uri = Uri.tryParse(link);
  if (uri != null) {
    try {
      final res = await http
          .head(uri)
          .timeout(const Duration(milliseconds: 10000));
      renderingType =
          res.headers['content-type']?.toMimeType ?? RenderingType.webview;
    } catch (_) {
      renderingType = RenderingType.webview;
    }
  }
  return renderingType;
}

/// Maps HTTP Content-Type header value to rendering type string.
/// Matches the MIME-to-rendering-type mapping used for asset token preview.
extension ContentTypeToMimeType on String {
  /// Returns the rendering type string (e.g. 'image', 'video', 'webview').
  String get toMimeType {
    final value = split(';').first.trim().toLowerCase();
    switch (value) {
      case 'image/avif':
      case 'image/bmp':
      case 'image/jpeg':
      case 'image/jpg':
      case 'image/png':
      case 'image/tiff':
        return RenderingType.image;

      case 'image/svg+xml':
        return RenderingType.svg;

      case 'image/gif':
      case 'image/vnd.mozilla.apng':
        return RenderingType.gif;

      case 'audio/aac':
      case 'audio/midi':
      case 'audio/x-midi':
      case 'audio/mpeg':
      case 'audio/ogg':
      case 'audio/opus':
      case 'audio/wav':
      case 'audio/webm':
      case 'audio/3gpp':
      case 'audio/vnd.wave':
        return RenderingType.audio;

      case 'video/x-msvideo':
      case 'video/3gpp':
      case 'video/mp4':
      case 'video/mpeg':
      case 'video/ogg':
      case 'video/3gpp2':
      case 'video/quicktime':
      case 'application/x-mpegurl':
      case 'video/x-flv':
      case 'video/mp2t':
      case 'video/webm':
      case 'application/octet-stream':
        return RenderingType.video;

      case 'application/pdf':
        return RenderingType.pdf;

      case 'model/gltf-binary':
        return RenderingType.modelViewer;

      default:
        return RenderingType.webview;
    }
  }
}
