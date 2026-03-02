import 'dart:async';

import 'package:app/app/providers/add_address_provider.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/ui/screens/add_address_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'AddAddressScreen auto-focuses the address input',
    (tester) async {
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
    },
  );

  testWidgets(
    'shows duplicate inline error when already added',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            addAddressProvider.overrideWith(
              () => _FakeAddAddressNotifierError(
                AddAddressException(type: AddAddressExceptionType.alreadyAdded),
              ),
            ),
          ],
          child: const MaterialApp(
            home: AddAddressScreen(
              payload: AddAddressScreenPayload(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('This address is already added. Enter a different address.'),
        findsOneWidget,
      );
    },
  );
}

class _FakeAddAddressNotifierError extends AddAddressNotifier {
  _FakeAddAddressNotifierError(this._error);

  final Exception _error;

  @override
  FutureOr<Address?> build() {
    return Future<Address?>.error(_error, StackTrace.current);
  }
}
