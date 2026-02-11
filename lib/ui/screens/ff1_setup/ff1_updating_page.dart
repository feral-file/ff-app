import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// FF1 updating page
class FF1UpdatingPage extends StatelessWidget {
  /// Constructor
  const FF1UpdatingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // User tried to use hardware back button or swipe back gesture
          // Navigate to home instead of popping

          context.go(Routes.home);
        }
      },
      child: Scaffold(
        appBar: SetupAppBar(
          onBack: () {
            context.go(Routes.home);
          },
          withDivider: false,
        ),
        backgroundColor: PrimitivesTokens.colorsDarkGrey,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/images/ff_logo.png',
                      width: 139,
                      height: 92.67,
                    ),
                    const SizedBox(height: 85),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Updating FF1',
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '''This update typically takes 5–10 min and FF1 may restart.\n\nKeep it powered and connected. Setup will continue when ready.''',
                            style: AppTypography.body(context).white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Positioned(
                //   bottom: LayoutConstants.space4,
                //   left: 0,
                //   right: 0,
                //   child: PrimaryAsyncButton(
                //     onTap: () async {
                //       // check the device status
                //       // if the device is updated, show the FF1 settings page
                //     },
                //     text: 'Check again',
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
