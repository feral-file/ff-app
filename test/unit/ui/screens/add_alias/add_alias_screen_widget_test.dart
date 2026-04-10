import 'package:app/app/providers/add_address_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/ui/screens/add_alias_screen.dart';
import 'package:app/widgets/buttons/outline_button.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'AddAliasScreen shows Skip when empty and Submit when non-empty',
    (tester) async {
      final calls = <_AddAliasCall>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nowDisplayingShouldShowProvider.overrideWithValue(false),
            addAliasProvider.overrideWith(
              () => _RecordingAddAliasNotifier(calls),
            ),
          ],
          child: const MaterialApp(
            home: AddAliasScreen(
              payload: AddAliasScreenPayload(
                address: '0xabc',
                domain: 'ff.example',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Submit'), findsNothing);

      final skipButton = tester.widget<OutlineButton>(
        find.byType(OutlineButton),
      );
      expect(skipButton.textColor, PrimitivesTokens.colorsWhite);
      expect(skipButton.borderColor, PrimitivesTokens.colorsWhite);

      await tester.enterText(find.byType(TextField), 'Alice');
      await tester.pump();

      expect(find.text('Skip'), findsNothing);
      expect(find.text('Submit'), findsOneWidget);

      final submitButton = tester.widget<PrimaryButton>(
        find.byType(PrimaryButton),
      );
      expect(submitButton.color, PrimitivesTokens.colorsWhite);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Submit'), findsNothing);

      expect(calls, isEmpty, reason: 'Typing must not submit automatically.');
    },
  );

  testWidgets('AddAliasScreen Skip calls addAlias with domain', (tester) async {
    final calls = <_AddAliasCall>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowDisplayingShouldShowProvider.overrideWithValue(false),
          addAliasProvider.overrideWith(
            () => _RecordingAddAliasNotifier(calls),
          ),
        ],
        child: const MaterialApp(
          home: AddAliasScreen(
            payload: AddAliasScreenPayload(
              address: '0xabc',
              domain: 'ff.example',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.address, '0xabc');
    expect(calls.single.alias, 'ff.example');
  });

  testWidgets('AddAliasScreen Submit calls addAlias with trimmed input', (
    tester,
  ) async {
    final calls = <_AddAliasCall>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nowDisplayingShouldShowProvider.overrideWithValue(false),
          addAliasProvider.overrideWith(
            () => _RecordingAddAliasNotifier(calls),
          ),
        ],
        child: const MaterialApp(
          home: AddAliasScreen(
            payload: AddAliasScreenPayload(
              address: '0xabc',
              domain: 'ff.example',
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '  Alice  ');
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(calls, hasLength(1));
    expect(calls.single.address, '0xabc');
    expect(calls.single.alias, 'Alice');
  });

  testWidgets(
    'GoRouter: AddAliasScreen auto-focuses alias field after push',
    (tester) async {
      const payload = AddAliasScreenPayload(
        address: '0x1234567890123456789012345678901234567890',
        domain: 'ff.example',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nowDisplayingShouldShowProvider.overrideWithValue(false),
            addAliasProvider.overrideWith(_StallAliasNotifier.new),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: Routes.home,
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => context.push(
                          Routes.addAliasPage,
                          extra: payload,
                        ),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.addAliasPage,
                  builder: (context, state) {
                    final extra = state.extra! as AddAliasScreenPayload;
                    return AddAliasScreen(payload: extra);
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode, isNotNull);
      expect(field.focusNode!.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GoRouter: Skip completes flow and pops twice (three-level stack)',
    (tester) async {
      final observer = _RecordingNavigatorObserver();
      const payload = AddAliasScreenPayload(
        address: '0x1234567890123456789012345678901234567890',
        domain: 'ff.example',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nowDisplayingShouldShowProvider.overrideWithValue(false),
            addAliasProvider.overrideWith(_ImmediateAliasSuccessNotifier.new),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              observers: [observer],
              routes: [
                GoRoute(
                  path: Routes.home,
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => context.push('/mid'),
                        child: const Text('Open'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/mid',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => context.push(
                          Routes.addAliasPage,
                          extra: payload,
                        ),
                        child: const Text('To alias'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.addAliasPage,
                  builder: (context, state) {
                    final extra = state.extra! as AddAliasScreenPayload;
                    return AddAliasScreen(payload: extra);
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('To alias'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(observer.popCount, 2);
      expect(find.text('Open'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _StallAliasNotifier extends AddAliasNotifier {
  @override
  Future<void> add(String address, String? alias) async {
    state = const AsyncValue.loading();
  }
}

class _ImmediateAliasSuccessNotifier extends AddAliasNotifier {
  @override
  Future<void> add(String address, String? alias) async {
    state = const AsyncValue.loading();
    state = const AsyncValue.data(null);
  }
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int popCount = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}

class _AddAliasCall {
  const _AddAliasCall({
    required this.address,
    required this.alias,
  });

  final String address;
  final String? alias;
}

class _RecordingAddAliasNotifier extends AddAliasNotifier {
  _RecordingAddAliasNotifier(this.calls);

  final List<_AddAliasCall> calls;

  @override
  Future<void> add(String address, String? alias) async {
    calls.add(_AddAliasCall(address: address, alias: alias));
    state = const AsyncValue.loading();
  }
}
