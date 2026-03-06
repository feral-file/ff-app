import 'dart:async';

import 'package:app/app/providers/add_address_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
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
            home: AddAddressScreen(),
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
            home: AddAddressScreen(),
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

  testWidgets(
    'Onboarding flow skips alias screen for ENS domain input',
    (tester) async {
      await _assertDomainInputSkipsAliasScreen(
        tester,
        domain: 'alice.eth',
      );
    },
  );

  testWidgets(
    'Onboarding flow skips alias screen for TNS domain input',
    (tester) async {
      await _assertDomainInputSkipsAliasScreen(
        tester,
        domain: 'alice.tez',
      );
    },
  );

  testWidgets(
    'Menu add-address flow also skips alias screen for domain input',
    (tester) async {
      await _assertDomainInputSkipsAliasScreen(
        tester,
        domain: 'menu.example',
      );
    },
  );

  testWidgets(
    'Pressing keyboard done/enter submits domain input',
    (tester) async {
      await _assertDomainInputSkipsAliasScreen(
        tester,
        domain: 'alice.eth',
        submitByKeyboardAction: true,
      );
    },
  );
}

Future<void> _assertDomainInputSkipsAliasScreen(
  WidgetTester tester, {
  required String domain,
  bool submitByKeyboardAction = false,
}) async {
  final calls = <_AddAliasCall>[];

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nowDisplayingShouldShowProvider.overrideWithValue(false),
        addAddressProvider.overrideWith(
          () => _FakeDomainVerifyAddAddressNotifier(domain: domain),
        ),
        addAliasProvider.overrideWith(
          () => _RecordingAddAliasNotifier(calls),
        ),
      ],
      child: const MaterialApp(
        home: AddAddressScreen(),
      ),
    ),
  );

  await tester.enterText(find.byType(TextField), domain);
  await tester.tap(find.byType(TextField));
  await tester.pump();

  if (submitByKeyboardAction) {
    await tester.testTextInput.receiveAction(TextInputAction.done);
  } else {
    await tester.tap(find.text('Submit'));
  }
  await tester.pump();
  await tester.pump();

  expect(calls, hasLength(1));
  expect(
    calls.single.address,
    '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8',
  );
  expect(calls.single.alias, domain);
  expect(calls.single.syncNow, isTrue);
  expect(find.text('Alias (optional)'), findsNothing);
}

class _FakeAddAddressNotifierError extends AddAddressNotifier {
  _FakeAddAddressNotifierError(this._error);

  final Exception _error;

  @override
  FutureOr<Address?> build() {
    return Future<Address?>.error(_error, StackTrace.current);
  }
}

class _FakeDomainVerifyAddAddressNotifier extends AddAddressNotifier {
  _FakeDomainVerifyAddAddressNotifier({
    required this.domain,
  });

  final String domain;

  @override
  Future<void> verify(String addressOrDomain) async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(
      Address(
        address: '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8',
        type: Chain.ethereum,
        domain: domain,
      ),
    );
  }
}

class _AddAliasCall {
  const _AddAliasCall({
    required this.address,
    required this.alias,
    required this.syncNow,
  });

  final String address;
  final String? alias;
  final bool syncNow;
}

class _RecordingAddAliasNotifier extends AddAliasNotifier {
  _RecordingAddAliasNotifier(this.calls);

  final List<_AddAliasCall> calls;

  @override
  Future<void> add(
    String address,
    String? alias, {
    bool syncNow = true,
  }) async {
    calls.add(_AddAliasCall(address: address, alias: alias, syncNow: syncNow));
    state = const AsyncValue.data(null);
  }
}
