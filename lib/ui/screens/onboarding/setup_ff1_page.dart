//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/onboarding/onboarding_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

final Logger _log = Logger('OnboardingSetupFf1Page');

/// Onboarding step: setup FF1.
class OnboardingSetupFf1Page extends ConsumerWidget {
  /// Creates a OnboardingSetupFf1Page.
  const OnboardingSetupFf1Page({
    super.key,
  });

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
            SizedBox(height: ContentRhythm.titleSupportGap),
            Text(
              "When you're ready to see these playlists on a wall, plug "
              'FF1 into any HDMI display and pair it with the app. Press '
              'Play and your screen becomes a surface for digital and '
              'computational art.',
              style: ContentRhythm.title(context),
            ),
            SizedBox(height: ContentRhythm.titleSupportGap),
            GestureDetector(
              onTap: () => onLearnMore(context),
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Learn more about the FF1 Art Computer',
                style: ContentRhythm.supporting(context).underline,
              ),
            ),
          ],
        ),
        primaryAction: OnboardingShellAction(
          key: GoldPathPatrolKeys.onboardingSetupFf1Primary,
          onPressed: () => _onSetupFf1(context, ref),
          child: Row(
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
        ),
        secondaryAction: OnboardingShellAction(
          key: GoldPathPatrolKeys.onboardingSetupFf1Secondary,
          onPressed: () => _onFinish(context, ref),
          child: Row(
            children: [
              Text(
                'Finish',
                style: AppTypography.body(context).lightBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// On setup FF1 button pressed.
  void _onSetupFf1(BuildContext context, WidgetRef ref) {
    ref.read(ff1SetupOrchestratorProvider.notifier).ensureActiveSetupSession();
    unawaited(context.push(Routes.ff1DeviceScanPage));
  }

  Future<void> _onFinish(BuildContext context, WidgetRef ref) async {
    final onboardingActions = ref.read(onboardingActionsProvider);
    unawaited(onboardingActions.completeOnboarding());
    context.go(Routes.home);
  }

  /// On learn more button pressed.
  Future<void> onLearnMore(BuildContext context) async {
    try {
      final uri = Uri.parse('https://feralfile.com/install');
      if (!uri.hasScheme) return;

      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException catch (e) {
      _log.warning('Failed to open learn more URL: $e');
    }
  }
}
