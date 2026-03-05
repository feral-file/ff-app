import 'package:app/widgets/delayed_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DelayedLoadingGate', () {
    testWidgets('does not show child before delay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DelayedLoadingGate(
              isLoading: true,
              child: Text('Loading'),
            ),
          ),
        ),
      );

      expect(find.text('Loading'), findsNothing);

      await tester.pump(const Duration(milliseconds: 499));
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('shows child after delay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DelayedLoadingGate(
              isLoading: true,
              child: Text('Loading'),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Loading'), findsOneWidget);
    });

    testWidgets('hides child when loading stops', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DelayedLoadingGate(
              isLoading: true,
              child: Text('Loading'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Loading'), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DelayedLoadingGate(
              isLoading: false,
              child: Text('Loading'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Loading'), findsNothing);
    });
  });
}
