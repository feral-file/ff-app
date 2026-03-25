import 'package:logging/logging.dart';
import 'package:webview_flutter/webview_flutter.dart';

final _log = Logger('WebViewControllerExtension');

extension WebViewControllerExtension on WebViewController {
  Future<void> evaluateJavascript({required String source}) async {
    try {
      await runJavaScript(source);
    } catch (e) {
      _log.fine('evaluateJavascript failed: $e');
    }
  }

  Future<void> mute() async {
    await evaluateJavascript(
      source:
          "var video = document.getElementsByTagName('video')[0]; "
          'if(video != undefined) { video.muted = true; } '
          "var audio = document.getElementsByTagName('audio')[0]; "
          'if(audio != undefined) { audio.muted = true; }',
    );
  }

  Future<void> skipPrint() async {
    await evaluateJavascript(
      source: "window.print = function () { console.log('Skip printing'); };",
    );
  }

  Future<void> onDispose() async {
    try {
      _log.info('WebViewController onDispose - clearing cache');
      // Clear cache to free memory and trigger cleanup of associated resources
      await clearCache();
      _log.info('WebViewController onDispose - cleanup complete');
    } catch (e) {
      _log.warning('Error during WebViewController cleanup: $e');
      // Don't rethrow - we want graceful cleanup even if individual steps fail
    }
  }

  void load(Uri uri, String? overriddenHtml) {
    if (overriddenHtml != null) {
      loadHtmlString(
        overriddenHtml,
      );
    } else {
      loadRequest(uri);
    }
  }
}
