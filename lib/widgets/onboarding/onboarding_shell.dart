//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
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
    this.onPrimaryPressed,
    this.secondaryButton,
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

  /// Optional label for the secondary (left) button – e.g., "Add Address", "Setup FF1".
  final Widget? secondaryButton;

  /// Optional callback for the secondary button.
  final VoidCallback? onSecondaryPressed;

  /// Whether to show the white bottom progress line.
  final bool showBottomProgress;

  /// Optional hint text.
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: LayoutConstants.setupPageHorizontal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            height: 206.94,
          ),
          Container(
            constraints: const BoxConstraints(
              minHeight: 245.06,
            ),
            child: content,
          ),
          SizedBox(height: LayoutConstants.space2),
          _buildButtonsRow(context),
          if (hintText != null) ...[
            SizedBox(height: LayoutConstants.space5),
            Text(
              hintText!,
              style: AppTypography.body(context).copyWith(
                color: PrimitivesTokens.colorsGrey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButtonsRow(BuildContext context) {
    // Keep layout close to Figma: two pill-shaped buttons,
    // left = secondary (outline), right = primary (filled).
    return Row(
      children: [
        Expanded(
          child: (primaryButton != null && onPrimaryPressed != null)
              ? CustomPrimaryButton(
                  padding: EdgeInsets.symmetric(
                    vertical: LayoutConstants.space3,
                  ),
                  onTap: onPrimaryPressed,
                  child: primaryButton!,
                )
              : const SizedBox.shrink(),
        ),
        SizedBox(width: LayoutConstants.space3),
        Expanded(
          child: (secondaryButton != null && onSecondaryPressed != null)
              ? CustomPrimaryButton(
                  padding:
                      EdgeInsets.symmetric(vertical: LayoutConstants.space3),
                  onTap: onSecondaryPressed,
                  borderColor: AppColor.feralFileLightBlue,
                  color: Colors.transparent,
                  child: secondaryButton!,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
