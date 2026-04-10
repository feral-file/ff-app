import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/ui/screens/ff1_setup/start_setup_ff1_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disposing start setup page cancels guided setup session', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        ff1SetupOrchestratorProvider.overrideWith(
          _TrackingSetupOrchestrator.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: StartSetupFf1Page(payload: StartSetupFf1PagePayload()),
        ),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    final notifier =
        container.read(ff1SetupOrchestratorProvider.notifier)
            as _TrackingSetupOrchestrator;
    expect(notifier.cancelReasons, [FF1SetupSessionCancelReason.userAborted]);
  });
}

class _TrackingSetupOrchestrator extends FF1SetupOrchestratorNotifier {
  final List<FF1SetupSessionCancelReason> cancelReasons = [];

  @override
  FF1SetupState build() {
    return const FF1SetupState(step: FF1SetupStep.idle);
  }

  @override
  Future<void> cancelSession(FF1SetupSessionCancelReason reason) async {
    cancelReasons.add(reason);
  }
}
