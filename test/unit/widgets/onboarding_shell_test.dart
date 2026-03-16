import 'package:app/widgets/onboarding/onboarding_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'OnboardingShell does not overflow on compact height',
    (tester) async {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      await binding.setSurfaceSize(const Size(302, 406));
      addTearDown(() async {
        await binding.setSurfaceSize(null);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingShell(
              content: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('See the art you already own'),
                  SizedBox(height: 16),
                  Text(
                    'Add your Ethereum and Tezos addresses to pull in the '
                    'works you collect. Use the app as a clear lens on your '
                    'digital collection, even before you connect a device.',
                  ),
                  SizedBox(height: 16),
                  SizedBox(height: 40, child: Text('reas.eth')),
                ],
              ),
              primaryButton: const Text('Add Address'),
              onPrimaryPressed: () {},
              secondaryButton: const Text('Next'),
              onSecondaryPressed: () {},
              hintText: 'You can always add addresses later.',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Next'), findsOneWidget);
    },
  );
}
