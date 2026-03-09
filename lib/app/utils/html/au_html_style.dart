import 'package:app/theme/app_color.dart';
import 'package:html/dom.dart' as dom;

/// Custom HTML styles for [HtmlWidget], matching old repo auHtmlStyle.
Map<String, String>? auHtmlStyle(dom.Element element) {
  if (element.localName == 'a') {
    const linkColor = AppColor.feralFileHighlight;
    final hexColor =
        '#${(linkColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return {
      'color': hexColor,
      'text-decoration': 'none',
    };
  }
  return {'user-select': 'text'};
}
