import 'dart:async';

import 'package:app/app/providers/add_address_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/ui/screens/add_address_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('AddAddressScreen auto-focuses the address input', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddAddressScreen(),
        ),
      ),
    );

    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.focusNode, isNotNull);
    expect(textField.focusNode!.hasFocus, isTrue);
  });

  testWidgets('shows duplicate inline error when already added', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addAddressFlowProvider.overrideWith(
            () => _ErrorAddAddressFlowNotifier(
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
  });

  testWidgets('Pressing keyboard done submits input', (tester) async {
    final notifier = _RecordingSubmitFlowNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowDisplayingShouldShowProvider.overrideWithValue(false),
          addAddressFlowProvider.overrideWith(() => notifier),
        ],
        child: const MaterialApp(
          home: AddAddressScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'alice.eth');
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(notifier.submitCount, 1);
    expect(notifier.lastInput, 'alice.eth');
  });

  testWidgets('Domain add returns to previous screen after success', (
    tester,
  ) async {
    final observer = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowDisplayingShouldShowProvider.overrideWithValue(false),
          addAddressFlowProvider.overrideWith(
            _DomainCompleteFlowNotifier.new,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            observers: [observer],
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => context.push('/add'),
                      child: const Text('Open'),
                    ),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (context, state) => const AddAddressScreen(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'alice.eth');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(observer.popCount, 1);
    expect(find.text('Open'), findsOneWidget);
  });
}

class _ErrorAddAddressFlowNotifier extends AddAddressFlowNotifier {
  _ErrorAddAddressFlowNotifier(this._error);

  final Exception _error;

  @override
  FutureOr<AddAddressFlowResult> build() {
    return Future<AddAddressFlowResult>.error(_error, StackTrace.current);
  }
}

class _RecordingSubmitFlowNotifier extends AddAddressFlowNotifier {
  int submitCount = 0;
  String? lastInput;

  @override
  Future<void> submit(String addressOrDomain) async {
    submitCount += 1;
    lastInput = addressOrDomain.trim();
    state = const AsyncValue.loading();
    state = const AsyncValue.data(AddAddressFlowIdle());
  }
}

class _DomainCompleteFlowNotifier extends AddAddressFlowNotifier {
  @override
  Future<void> submit(String addressOrDomain) async {
    state = const AsyncValue.loading();
    state = const AsyncValue.data(AddAddressFlowCompleted());
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount += 1;
    super.didPop(route, previousRoute);
  }
}
