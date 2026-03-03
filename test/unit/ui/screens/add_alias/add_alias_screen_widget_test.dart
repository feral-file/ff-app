import 'package:app/app/providers/add_address_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/ui/screens/add_alias_screen.dart';
import 'package:app/widgets/buttons/outline_button.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
              syncNow: false,
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
    expect(calls.single.syncNow, isFalse);
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
    expect(calls.single.syncNow, isTrue);
  });
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
    state = const AsyncValue.loading();
  }
}
