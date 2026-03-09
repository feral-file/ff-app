import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Stub for keyboard input to webview. Matches old repo widget tree;
/// maintains same constructor signature for parity with artwork_detail_page.
class WebviewControllerTextField extends StatelessWidget {
  const WebviewControllerTextField({
    required this.focusNode,
    required this.textController,
    super.key,
    this.disableKeys = const [],
    this.webViewController,
  });

  final WebViewController? webViewController;
  final FocusNode focusNode;
  final TextEditingController textController;
  final List<String> disableKeys;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: 0,
        child: IgnorePointer(
          child: TextFormField(
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            controller: textController,
            focusNode: focusNode,
          ),
        ),
      );
}
