import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:app/app/keyboard_visibility_override.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/app/route_observer.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/view/get_dark_empty_app_bar.dart';
import 'package:app/widgets/touchpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keyboard control (interact) screen. Data from [nowDisplayingProvider].
/// UI copied from old repo; devices = [connectedDevice] when now displaying success.
class KeyboardControlScreen extends ConsumerWidget {
  const KeyboardControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(nowDisplayingProvider);

    if (status is! NowDisplayingSuccess) {
      return Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        appBar: getDarkEmptyAppBar(AppColor.auGreyBackground),
        body: const Center(
          child: Text('No device connected'),
        ),
      );
    }

    final object = status.object;
    if (object is! DP1NowDisplayingObject) {
      return Scaffold(
        backgroundColor: AppColor.auGreyBackground,
        appBar: getDarkEmptyAppBar(AppColor.auGreyBackground),
        body: const Center(
          child: Text('No device connected'),
        ),
      );
    }

    final topicId = object.connectedDevice.topicId;
    return _KeyboardControlContent(topicId: topicId);
  }
}

class _KeyboardControlContent extends ConsumerStatefulWidget {
  const _KeyboardControlContent({required this.topicId});

  final String topicId;

  @override
  ConsumerState<_KeyboardControlContent> createState() =>
      _KeyboardControlContentState();
}

class _KeyboardControlContentState
    extends ConsumerState<_KeyboardControlContent>
    with AfterLayoutMixin, WidgetsBindingObserver, RouteAware {
  final _focusNode = FocusNode();
  final _controller = KeyboardVisibilityController();
  StreamSubscription<bool>? _keyboardSubscription;
  final _textController = TextEditingController();

  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    unawaited(_keyboardSubscription?.cancel());
    _textController.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    setState(() {
      _isExpanded = false;
    });
  }

  @override
  void didPushNext() {
    super.didPushNext();
    setState(() {
      _isExpanded = true;
    });
  }

  @override
  void afterFirstLayout(BuildContext context) {
    shouldHideKeyboardOnTap.value = false;
    _focusNode.requestFocus();
    final navigator = Navigator.of(context);
    _keyboardSubscription = _controller.onChange.listen((bool isVisible) {
      if (!isVisible && !_isExpanded) {
        shouldHideKeyboardOnTap.value = true;
        if (mounted) {
          navigator.pop();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wifiControl = ref.read(ff1WifiControlProvider);

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      resizeToAvoidBottomInset: false,
      appBar: getDarkEmptyAppBar(AppColor.auGreyBackground),
      body: KeyboardVisibilityBuilder(
        builder: (context, isKeyboardVisible) {
          return Padding(
            padding: MediaQuery.of(context).viewInsets,
            child: Column(
              children: [
                SizedBox(
                  height: 1,
                  child: TextField(
                    focusNode: _focusNode,
                    controller: _textController,
                    autofocus: true,
                    cursorColor: Colors.transparent,
                    showCursor: false,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableInteractiveSelection: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                    ),
                    onChanged: (_) async {
                      final text = _textController.text;
                      if (text.isEmpty) return;
                      final code = text[text.length - 1];
                      _textController.clear();
                      await wifiControl.keyboardEvent(
                        topicId: widget.topicId,
                        code: code.codeUnitAt(0),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Container(
                    color: AppColor.auGreyBackground,
                    padding: EdgeInsets.all(LayoutConstants.space4),
                    child: Column(
                      children: [
                        Expanded(
                          child: TouchPad(topicId: widget.topicId),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
