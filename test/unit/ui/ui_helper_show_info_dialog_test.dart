import 'dart:async';

import 'package:app/app/providers/services_provider.dart';
import 'package:app/infra/services/device_info_service.dart';
import 'package:app/infra/services/support_email_service.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'showInfoDialog closes safely after the launching widget unmounts',
    (tester) async {
      final harnessKey = GlobalKey<_DialogHarnessState>();

      await tester.pumpWidget(
        MaterialApp(home: _DialogHarness(key: harnessKey)),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Dialog body'), findsOneWidget);

      harnessKey.currentState!.unmountLauncher();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Dialog body'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'showInfoDialog runs onClose after dismissing with the dialog context',
    (tester) async {
      var closeCount = 0;
      final harnessKey = GlobalKey<_DialogHarnessState>();

      await tester.pumpWidget(
        MaterialApp(
          home: _DialogHarness(
            key: harnessKey,
            onClose: (_) {
              closeCount++;
            },
          ),
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      harnessKey.currentState!.unmountLauncher();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(closeCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'showInfoDialog auto-dismisses safely after the launching widget unmounts',
    (tester) async {
      final harnessKey = GlobalKey<_DialogHarnessState>();

      await tester.pumpWidget(
        MaterialApp(
          home: _DialogHarness(
            key: harnessKey,
            autoDismissAfter: 1,
          ),
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Dialog body'), findsOneWidget);

      harnessKey.currentState!.unmountLauncher();
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Dialog body'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'showInfoDialog can launch support dialog after the launcher unmounts',
    (tester) async {
      final harnessKey = GlobalKey<_DialogHarnessState>();
      final supportEmailService = SupportEmailService(
        deviceInfoService: DeviceInfoService(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: _DialogHarness(
            key: harnessKey,
            closeButton: 'Contact support',
            onClose: (nextContext) {
              return UIHelper.showCustomerSupport(
                nextContext,
                supportEmailService: supportEmailService,
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      harnessKey.currentState!.unmountLauncher();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contact support'));
      await tester.pumpAndSettle();

      expect(find.text('Attach a debug log?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'captured support service still opens support dialog '
    'after disposed ref path',
    (tester) async {
      final harnessKey = GlobalKey<_ConsumerDialogHostState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supportEmailServiceProvider.overrideWith(
              (ref) => _StubSupportEmailService(),
            ),
          ],
          child: MaterialApp(
            home: _ConsumerDialogHost(key: harnessKey),
          ),
        ),
      );

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      harnessKey.currentState!.unmountChild();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contact support'));
      await tester.pumpAndSettle();

      expect(find.text('Attach a debug log?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

}

class _DialogHarness extends StatefulWidget {
  const _DialogHarness({
    super.key,
    this.onClose,
    this.autoDismissAfter = 0,
    this.closeButton = 'Close',
  });

  final FutureOr<void> Function(BuildContext nextContext)? onClose;
  final int autoDismissAfter;
  final String closeButton;

  @override
  State<_DialogHarness> createState() => _DialogHarnessState();
}

class _DialogHarnessState extends State<_DialogHarness> {
  bool _showLauncher = true;

  void unmountLauncher() {
    setState(() {
      _showLauncher = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (_showLauncher)
            Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  unawaited(
                    UIHelper.showInfoDialog(
                      context,
                      'Dialog title',
                      'Dialog body',
                      autoDismissAfter: widget.autoDismissAfter,
                      closeButton: widget.closeButton,
                      onClose: widget.onClose,
                    ),
                  );
                },
                child: const Text('Open dialog'),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConsumerDialogHost extends StatefulWidget {
  const _ConsumerDialogHost({super.key});

  @override
  State<_ConsumerDialogHost> createState() => _ConsumerDialogHostState();
}

class _ConsumerDialogHostState extends State<_ConsumerDialogHost> {
  bool _showChild = true;

  void unmountChild() {
    setState(() {
      _showChild = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showChild ? const _ConsumerDialogLauncher() : const SizedBox(),
    );
  }
}

class _ConsumerDialogLauncher extends ConsumerWidget {
  const _ConsumerDialogLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: TextButton(
        onPressed: () {
          final supportEmailService = ref.read(supportEmailServiceProvider);
          unawaited(
            UIHelper.showInfoDialog(
              context,
              'Dialog title',
              'Dialog body',
              closeButton: 'Contact support',
              onClose: (nextContext) {
                return UIHelper.showCustomerSupport(
                  nextContext,
                  supportEmailService: supportEmailService,
                );
              },
            ),
          );
        },
        child: const Text('Open dialog'),
      ),
    );
  }
}

class _StubSupportEmailService extends SupportEmailService {
  _StubSupportEmailService() : super(deviceInfoService: DeviceInfoService());

  @override
  Future<void> composeSupportEmail({
    required String recipient,
    bool attachLogs = true,
  }) async {}
}
