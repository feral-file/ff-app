//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/buttons/custom_primary_button.dart';
import 'package:flutter/material.dart';

/// Generic shell widget for new onboarding screens.
///
/// This widget encapsulates the common layout from the FF1 Art Computer
/// onboarding designs:
/// - Dark background
/// - Centered content block (title, body, custom widgets, etc.)
/// - Two action buttons at the bottom
/// - Optional bottom progress indicator line
class OnboardingShell extends StatelessWidget {
  /// Creates a OnboardingShell.
  const OnboardingShell({
    required this.content,
    super.key,
    this.primaryButton,
    this.primaryButtonKey,
    this.onPrimaryPressed,
    this.secondaryButton,
    this.secondaryButtonKey,
    this.onSecondaryPressed,
    this.showBottomProgress = true,
    this.hintText,
  });

  /// Main content of the onboarding step (usually title + body + illustration).
  final Widget content;

  /// Label for the primary (right) button – e.g., "Next", "Finish".
  final Widget? primaryButton;

  /// Callback when the primary button is pressed.
  final VoidCallback? onPrimaryPressed;

  /// Optional semantic key for the primary button.
  final Key? primaryButtonKey;

  /// Optional label for the secondary (left) button.
  /// For example: "Add Address", "Setup FF1".
  final Widget? secondaryButton;

  /// Optional callback for the secondary button.
  final VoidCallback? onSecondaryPressed;

  /// Optional semantic key for the secondary button.
  final Key? secondaryButtonKey;

  /// Whether to show the white bottom progress line.
  final bool showBottomProgress;

  /// Optional hint text.
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: LayoutConstants.setupPageHorizontal,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height:
                        LayoutConstants.space20 +
                        LayoutConstants.space20 +
                        LayoutConstants.space12,
                  ),
                  content,
                  SizedBox(
                    height: LayoutConstants.space20 + LayoutConstants.space8,
                  ),
                  _buildButtonsRow(context),
                  if (hintText != null) ...[
                    SizedBox(height: LayoutConstants.space5),
                    Text(
                      hintText!,
                      style: ContentRhythm.supporting(context),
                    ),
                  ],
                  SizedBox(height: LayoutConstants.space4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildButtonsRow(BuildContext context) {
    final primary = (primaryButton != null && onPrimaryPressed != null)
        ? CustomPrimaryButton(
            key: primaryButtonKey,
            padding: EdgeInsets.symmetric(
              vertical: ContentRhythm.rowVerticalPadding,
            ),
            onTap: onPrimaryPressed,
            child: primaryButton!,
          )
        : const SizedBox.shrink();

    final secondary = (secondaryButton != null && onSecondaryPressed != null)
        ? CustomPrimaryButton(
            key: secondaryButtonKey,
            padding: EdgeInsets.symmetric(
              vertical: ContentRhythm.rowVerticalPadding,
            ),
            onTap: onSecondaryPressed,
            borderColor: AppColor.feralFileLightBlue,
            color: Colors.transparent,
            child: secondaryButton!,
          )
        : const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 245) {
          return Column(
            children: [
              SizedBox(width: double.infinity, child: primary),
              SizedBox(height: LayoutConstants.space2),
              SizedBox(width: double.infinity, child: secondary),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: primary),
            SizedBox(width: LayoutConstants.space3),
            Expanded(child: secondary),
          ],
        );
      },
    );
  }
}
