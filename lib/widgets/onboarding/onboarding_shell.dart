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

/// Describes one onboarding action button.
class OnboardingShellAction {
  /// Creates an onboarding action button model.
  const OnboardingShellAction({
    required this.child,
    required this.onPressed,
    this.key,
    this.borderColor,
    this.backgroundColor,
    this.enabled = true,
  });

  /// Button content widget.
  final Widget child;

  /// Callback for button press.
  final VoidCallback onPressed;

  /// Optional semantic key for automation.
  final Key? key;

  /// Optional border color override.
  final Color? borderColor;

  /// Optional background color override.
  final Color? backgroundColor;

  /// Whether the action is currently available.
  final bool enabled;
}

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
    this.primaryAction,
    this.secondaryAction,
    this.showBottomProgress = true,
    this.hintText,
  });

  /// Main content of the onboarding step (usually title + body + illustration).
  final Widget content;

  /// Primary (left) onboarding action.
  final OnboardingShellAction? primaryAction;

  /// Secondary (right) onboarding action.
  final OnboardingShellAction? secondaryAction;

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
    final primary = (primaryAction != null)
        ? CustomPrimaryButton(
            key: primaryAction!.key,
            padding: EdgeInsets.symmetric(
              vertical: ContentRhythm.rowVerticalPadding,
            ),
            onTap: primaryAction!.onPressed,
            enabled: primaryAction!.enabled,
            borderColor: primaryAction!.borderColor,
            color: primaryAction!.backgroundColor,
            child: primaryAction!.child,
          )
        : const SizedBox.shrink();

    final secondary = (secondaryAction != null)
        ? CustomPrimaryButton(
            key: secondaryAction!.key,
            padding: EdgeInsets.symmetric(
              vertical: ContentRhythm.rowVerticalPadding,
            ),
            onTap: secondaryAction!.onPressed,
            enabled: secondaryAction!.enabled,
            borderColor:
                secondaryAction!.borderColor ?? AppColor.feralFileLightBlue,
            color: secondaryAction!.backgroundColor ?? Colors.transparent,
            child: secondaryAction!.child,
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
