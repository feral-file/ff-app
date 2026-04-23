import 'package:app/widgets/ff_mouse_gesture_detector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FfMouseGestureDetector', () {
    testWidgets('single tap triggers onTap (deferred until double-tap timeout)', (tester) async {
      var tapCount = 0;
      var doubleTapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: FfMouseGestureDetector(
                onTap: () => tapCount++,
                onDoubleTap: () => doubleTapCount++,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(FfMouseGestureDetector));
      await tester.tapAt(center);
      await tester.pump();

      // Not yet fired: still waiting to see if this becomes a double tap.
      expect(tapCount, 0);
      expect(doubleTapCount, 0);

      await tester.pump(kDoubleTapTimeout);
      expect(tapCount, 1);
      expect(doubleTapCount, 0);
    });

    testWidgets('double tap triggers onDoubleTap and does not trigger onTap', (tester) async {
      var tapCount = 0;
      var doubleTapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: FfMouseGestureDetector(
                onTap: () => tapCount++,
                onDoubleTap: () => doubleTapCount++,
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(FfMouseGestureDetector));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pump();

      expect(doubleTapCount, 1);

      // If a single tap was pending, it should be cancelled by the double tap.
      await tester.pump(kDoubleTapTimeout);
      expect(tapCount, 0);
    });

    testWidgets('routes single drag to onMove', (tester) async {
      final moveDeltas = <Offset>[];
      final clickAndDragDeltas = <Offset>[];
      var longPressCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: FfMouseGestureDetector(
                  onTap: () {},
                  onDoubleTap: () {},
                  onMove: moveDeltas.add,
                  onClickAndDrag: clickAndDragDeltas.add,
                  onLongPress: () => longPressCount++,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(FfMouseGestureDetector));
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.moveBy(const Offset(30, 10));
      await tester.pump();
      await gesture.moveBy(const Offset(-5, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(moveDeltas, isNotEmpty);
      expect(clickAndDragDeltas, isEmpty);
      expect(longPressCount, 0);
    });

    testWidgets('routes double-tap-hold then drag to onClickAndDrag', (tester) async {
      final moveDeltas = <Offset>[];
      final clickAndDragDeltas = <Offset>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: FfMouseGestureDetector(
                  onTap: () {},
                  onDoubleTap: () {},
                  onMove: moveDeltas.add,
                  onClickAndDrag: clickAndDragDeltas.add,
                  onLongPress: () {},
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(FfMouseGestureDetector));

      // Tap #1 (down+up).
      await tester.tapAt(center);
      await tester.pump();

      // Tap #2 down, hold, then drag.
      await tester.pump(const Duration(milliseconds: 50));
      final gesture = await tester.startGesture(center);
      await tester.pump();
      await gesture.moveBy(const Offset(40, 0)); // exceed pan slop
      await tester.pump();
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(clickAndDragDeltas, isNotEmpty);
      expect(moveDeltas, isEmpty);
    });

    testWidgets('long press triggers onLongPress and does not emit move/clickAndDrag', (tester) async {
      final moveDeltas = <Offset>[];
      final clickAndDragDeltas = <Offset>[];
      var longPressCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: FfMouseGestureDetector(
                  onTap: () {},
                  onDoubleTap: () {},
                  onMove: moveDeltas.add,
                  onClickAndDrag: clickAndDragDeltas.add,
                  onLongPress: () => longPressCount++,
                  child: const ColoredBox(color: Colors.black),
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(FfMouseGestureDetector));
      await tester.longPressAt(center);
      await tester.pump();

      expect(longPressCount, 1);
      expect(moveDeltas, isEmpty);
      expect(clickAndDragDeltas, isEmpty);
    });
  });
}

