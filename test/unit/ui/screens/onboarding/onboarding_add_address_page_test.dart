import 'package:app/app/providers/addresses_provider.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/ui/screens/onboarding/onboarding_add_address_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _deleteAddressKey = ValueKey<String>(
  'onboarding.add_address.delete.0x1234567890123456789012345678901234567890',
);

void main() {
  testWidgets('shows waiting UI while startup seed sync gate is closed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressesProvider.overrideWith((ref) => Stream.value(const [])),
          onboardingAddAddressActionGateProvider.overrideWithValue(
            const OnboardingAddAddressActionGate(
              status: OnboardingAddAddressActionGateStatus.waitingForSeedSync,
              message:
                  'Preparing your library. You can add addresses in a moment.',
            ),
          ),
        ],
        child: MaterialApp(
          home: OnboardingAddAddressPage(
            payload: OnboardingAddAddressPagePayload(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Please wait'), findsOneWidget);
    expect(
      find.text('Address adds stay disabled while startup sync settles.'),
      findsOneWidget,
    );
    expect(
      find.text('Preparing your library. You can add addresses in a moment.'),
      findsOneWidget,
    );
  });

  testWidgets('does not allow deleting addresses while gate is closed', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressesProvider.overrideWith(
            (ref) => Stream.value([
              WalletAddress(
                address: '0x1234567890123456789012345678901234567890',
                name: 'alice.eth',
                createdAt: DateTime(2026),
              ),
            ]),
          ),
          onboardingAddAddressActionGateProvider.overrideWithValue(
            const OnboardingAddAddressActionGate(
              status: OnboardingAddAddressActionGateStatus.waitingForSeedSync,
              message:
                  'Preparing your library. You can add addresses in a moment.',
            ),
          ),
        ],
        child: MaterialApp(
          home: OnboardingAddAddressPage(
            payload: OnboardingAddAddressPagePayload(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(_deleteAddressKey),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete this address?'), findsNothing);
  });
}
