import 'package:app/ui/screens/settings/forget_exist_dialog_content.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Helper for settings-related dialogs (Forget I exist, etc.).
abstract final class SettingsDialogHelper {
  SettingsDialogHelper._();

  /// Shows the Forget I exist confirmation dialog.
  /// On confirm, clears local data and navigates to onboarding.
  static Future<void> showForgetExistDialog(
    BuildContext context,
    WidgetRef ref,
  ) {
    return UIHelper.showDialog<void>(
      context,
      'Forget I exist',
      const ForgetExistDialogContent(),
    );
  }
}
