//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/ui/screens/onboarding/onboarding_add_address_page.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/onboarding/onboarding_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// Introductory onboarding page:
/// "Explore digital art playlists"
///
/// This widget is implemented using [OnboardingShell] to match the Figma
/// screen:
/// FF1 Art Computer → Onboarding B 4.
///

class IntroducePagePayload {
  /// Constructor
  IntroducePagePayload({
    this.deeplink,
  });

  /// Optional deeplink carried through the onboarding flow.
  final String? deeplink;
}

/// Introduce page.
class IntroducePage extends StatelessWidget {
  /// Creates a IntroducePage.
  const IntroducePage({
    required this.payload,
    super.key,
  });

  /// Payload for the page
  final IntroducePagePayload payload;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrimitivesTokens.colorsDarkGrey,
      appBar: SetupAppBar(
        withDivider: false,
        hasBackButton: payload.deeplink != null,
      ),
      body: OnboardingShell(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explore digital art playlists',
              style: AppTypography.h2(context).white,
            ),
            SizedBox(height: ContentRhythm.titleSupportGap),
            Text(
              'Browse curated playlists and channels from Feral File and '
              'invited collaborators—right on your phone. You don’t need '
              'any hardware to start exploring.',
              style: ContentRhythm.title(context),
            ),
          ],
        ),
        primaryButton: Row(
          children: [
            Text(
              'Next',
              style: AppTypography.body(context).black,
            ),
            SizedBox(width: LayoutConstants.space2),
            SvgPicture.asset(
              'assets/images/arrow_right.svg',
              colorFilter: const ColorFilter.mode(
                PrimitivesTokens.colorsBlack,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
        onPrimaryPressed: () => onNext(context),
        primaryButtonKey: GoldPathPatrolKeys.onboardingIntroduceNext,
      ),
    );
  }

  /// Callback triggered when the user taps the "Next" button.
  void onNext(BuildContext context) {
    unawaited(
      context.push(
        Routes.onboardingAddAddressPage,
        extra: OnboardingAddAddressPagePayload(deeplink: payload.deeplink),
      ),
    );
  }
}
