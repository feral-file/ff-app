import 'package:app/ui/screens/add_address_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AddAddressScreen auto-focuses the address input', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddAddressScreen(
            payload: AddAddressScreenPayload(),
          ),
        ),
      ),
    );

    // Allow the post-frame focus request to run.
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode, isNotNull);
    expect(textField.focusNode!.hasFocus, isTrue);
  });
}

