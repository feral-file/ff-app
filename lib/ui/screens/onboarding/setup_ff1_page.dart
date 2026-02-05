//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/deeplink_handler.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/onboarding/onboarding_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// Onboarding step: setup FF1.
class OnboardingSetupFf1Page extends ConsumerWidget {
  /// Creates a OnboardingSetupFf1Page.
  const OnboardingSetupFf1Page({
    this.deeplink,
    super.key,
  });

  /// Optional deeplink carried through the onboarding flow.
  final String? deeplink;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: PrimitivesTokens.colorsDarkGrey,
      appBar: const SetupAppBar(
        withDivider: false,
      ),
      body: OnboardingShell(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add FF1 to your screens',
              style: AppTypography.h2(context).white,
            ),
            SizedBox(height: LayoutConstants.space5),
            Text(
              "When you're ready to see these playlists on a wall, plug "
              'FF1 into any HDMI display and pair it with the app. Press '
              'Play and your screen becomes a surface for digital and '
              'computational art.',
              style: AppTypography.body(context).white,
            ),
            SizedBox(height: LayoutConstants.space5),
            GestureDetector(
              onTap: () => onLearnMore(context),
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Learn more about the FF1 Art Computer',
                style: AppTypography.body(context).grey.underline,
              ),
            ),
          ],
        ),
        primaryButton: Row(
          children: [
            SvgPicture.asset(
              'assets/images/ff1.svg',
              colorFilter: const ColorFilter.mode(
                PrimitivesTokens.colorsBlack,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: LayoutConstants.space2),
            Text(
              'Setup FF1',
              style: AppTypography.body(context).black,
            ),
          ],
        ),
        onPrimaryPressed: () => _onSetupFf1(context, ref),
        secondaryButton: Row(
          children: [
            Text(
              'Finish',
              style: AppTypography.body(context).lightBlue,
            ),
          ],
        ),
        onSecondaryPressed: () async => _onFinish(context, ref),
      ),
    );
  }

  /// On setup FF1 button pressed.
  void _onSetupFf1(BuildContext context, WidgetRef ref) {
    if (!handleDeeplinkCompleter.isCompleted) {
      handleDeeplinkCompleter.complete();
    }

    final onboardingActions = ref.read(onboardingActionsProvider);
    unawaited(onboardingActions.completeOnboarding());
    context.go(Routes.ff1DevicePickerPage);
  }

  Future<void> _onFinish(BuildContext context, WidgetRef ref) async {
    if (!handleDeeplinkCompleter.isCompleted) {
      handleDeeplinkCompleter.complete();
    }

    final onboardingActions = ref.read(onboardingActionsProvider);
    unawaited(onboardingActions.completeOnboarding());
    context.go(Routes.home);
  }

  /// On learn more button pressed.
  void onLearnMore(BuildContext context) {
    // TODO(feral-file): implement FF1 learn-more navigation (e.g. open docs URL).
  }
}
