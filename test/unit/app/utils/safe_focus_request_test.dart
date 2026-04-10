import 'dart:async';

import 'package:app/app/utils/safe_focus_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'scheduleRequestFocusWhenLaidOut focuses TextField after layout',
    (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: _AutoFocusHarness(
            focusNode: focusNode,
            child: TextField(
              focusNode: focusNode,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);
    },
  );

  testWidgets(
    'scheduleRequestFocusWhenLaidOut retries when TextField not laid out yet',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: _LateTextFieldHarness(),
        ),
      );

      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
    },
  );

  testWidgets(
    'schedulePostFrameIfMounted runs action on next frame when route current',
    (tester) async {
      var ran = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    schedulePostFrameIfMounted(context, () {
                      ran = true;
                    });
                  },
                  child: const Text('go'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('go'));
      expect(ran, isFalse);
      await tester.pump();
      expect(ran, isTrue);
    },
  );

  testWidgets(
    'schedulePostFrameIfMounted skips action when route no longer current',
    (tester) async {
      var ran = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  onPressed: () {
                    schedulePostFrameIfMounted(context, () {
                      ran = true;
                    });
                    unawaited(
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const Scaffold(
                            body: Text('second'),
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('go'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('go'));
      expect(ran, isFalse);
      await tester.pump();
      expect(ran, isFalse);
    },
  );

  testWidgets(
    'schedulePostFrameIfMounted skips when context unmounted before callback',
    (tester) async {
      var ran = false;
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;
              return const Scaffold(
                body: Text('home'),
              );
            },
          ),
        ),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      schedulePostFrameIfMounted(captured, () {
        ran = true;
      });
      await tester.pump();
      expect(ran, isFalse);
    },
  );
}

class _AutoFocusHarness extends StatefulWidget {
  const _AutoFocusHarness({
    required this.focusNode,
    required this.child,
  });

  final FocusNode focusNode;
  final Widget child;

  @override
  State<_AutoFocusHarness> createState() => _AutoFocusHarnessState();
}

class _AutoFocusHarnessState extends State<_AutoFocusHarness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      scheduleRequestFocusWhenLaidOut(
        focusNode: widget.focusNode,
        ownerContext: context,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: widget.child);
  }
}

/// First frame has no [TextField], so the first focus attempt sees no layout;
/// the field is inserted in the same post-frame callback after scheduling
/// focus — exercising the retry path used for FF-APP-6J / issue #357.
class _LateTextFieldHarness extends StatefulWidget {
  const _LateTextFieldHarness();

  @override
  State<_LateTextFieldHarness> createState() => _LateTextFieldHarnessState();
}

class _LateTextFieldHarnessState extends State<_LateTextFieldHarness> {
  final FocusNode _focusNode = FocusNode();
  bool _insertField = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      scheduleRequestFocusWhenLaidOut(
        focusNode: _focusNode,
        ownerContext: context,
      );
      setState(() => _insertField = true);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _insertField
          ? TextField(
              focusNode: _focusNode,
            )
          : const SizedBox.shrink(),
    );
  }
}
