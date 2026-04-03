import 'package:app/widgets/appbars/main_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a blank back label when there is no previous title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: MainAppBar.preferred(context),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Back Button'), findsOneWidget);
    expect(find.text('Back'), findsNothing);
  });
}
