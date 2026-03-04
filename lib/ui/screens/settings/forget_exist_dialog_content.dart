import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:app/app/providers/local_data_cleanup_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/buttons/outline_button.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roundcheckbox/roundcheckbox.dart';

/// Bullet dot widget for the Forget I exist dialog list.
Widget _dotIcon({required Color color, double size = 6}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );

/// Dialog content for Forget I exist confirmation.
/// Copied from old ForgetExistView; uses Riverpod instead of BLoC.
class ForgetExistDialogContent extends ConsumerStatefulWidget {
  /// Creates a [ForgetExistDialogContent].
  const ForgetExistDialogContent({super.key});

  @override
  ConsumerState<ForgetExistDialogContent> createState() =>
      _ForgetExistDialogContentState();
}

class _ForgetExistDialogContentState
    extends ConsumerState<ForgetExistDialogContent> {
  bool _isChecked = false;

  Future<void> _onConfirm() async {
    if (!_isChecked) return;

    final router = GoRouter.of(context);
    final overlayNotifier = ref.read(appOverlayProvider.notifier);
    final cleanupService = ref.read(localDataCleanupServiceProvider);

    final toastOverlayId =
        overlayNotifier.showToast(message: 'Cleaning local data...');
    await WidgetsBinding.instance.endOfFrame;

    context.pop();
    router.go(Routes.home);

    try {
      await cleanupService
          .clearLocalData()
          .timeout(const Duration(seconds: 20));
    } on Object catch (_) {
      // Cleanup had issues but we still navigate to onboarding
    } finally {
      overlayNotifier.dismissOverlay(toastOverlayId);
      router.go(Routes.onboardingIntroducePage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This will permanently:',
          style: AppTypography.body(context).bold.copyWith(
            color: AppColor.white,
          ),
        ),
        SizedBox(height: LayoutConstants.space3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: LayoutConstants.space6),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _dotIcon(color: AppColor.white),
                      ),
                      SizedBox(width: LayoutConstants.space3),
                      Expanded(
                        child: Text(
                          'Remove your art addresses (view-only) and all '
                          'app data on this device.',
                          style: AppTypography.body(context).copyWith(
                            color: AppColor.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _dotIcon(color: AppColor.white),
                      ),
                      SizedBox(width: LayoutConstants.space3),
                      Expanded(
                        child: Text(
                          "Unpair this device from any FF1 you've connected.",
                          style: AppTypography.body(context).copyWith(
                            color: AppColor.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _dotIcon(color: AppColor.white),
                      ),
                      SizedBox(width: LayoutConstants.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete your playlists from Feral File and '
                              'stop sharing them:',
                              style: AppTypography.body(context).copyWith(
                                color: AppColor.white,
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: LayoutConstants.space6),
                                Text(
                                  'o ',
                                  style: AppTypography.body(context).copyWith(
                                    color: AppColor.white,
                                  ),
                                ),
                                SizedBox(width: LayoutConstants.space2),
                                Expanded(
                                  child: Text(
                                    'Others may briefly see cached copies; '
                                    "they won't update and will disappear "
                                    'after refresh.',
                                    style:
                                        AppTypography.body(context).copyWith(
                                      color: AppColor.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: LayoutConstants.space6),
                                Text(
                                  'o ',
                                  style: AppTypography.body(context).copyWith(
                                    color: AppColor.white,
                                  ),
                                ),
                                SizedBox(width: LayoutConstants.space2),
                                Expanded(
                                  child: Text(
                                    'If someone republished one of your '
                                    'playlists under their own feed, that '
                                    'copy will continue under their control '
                                    '(not yours).',
                                    style:
                                        AppTypography.body(context).copyWith(
                                      color: AppColor.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          "Once you continue, we can't recover this data.",
          style: AppTypography.body(context).bold.copyWith(
            color: AppColor.white,
          ),
        ),
        SizedBox(height: LayoutConstants.space8 + LayoutConstants.space4),
        GestureDetector(
          onTap: () => setState(() => _isChecked = !_isChecked),
          child: Row(
            children: [
              RoundCheckBox(
                size: 24,
                borderColor: theme.colorScheme.secondary,
                uncheckedColor: theme.colorScheme.primary,
                checkedColor: theme.colorScheme.secondary,
                isChecked: _isChecked,
                checkedWidget: Icon(
                  Icons.check,
                  color: theme.colorScheme.primary,
                  size: 14,
                ),
                onTap: (bool? value) {
                  setState(() => _isChecked = value ?? false);
                },
              ),
              SizedBox(width: LayoutConstants.space3 + LayoutConstants.space2),
              Expanded(
                child: Text(
                  'I understand that this action cannot be undone.',
                  style: AppTypography.body(context).copyWith(
                    color: AppColor.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: LayoutConstants.space10),
        PrimaryButton(
          text: 'Delete my information',
          color: _isChecked ? null : AppColor.disabledColor,
          onTap: _isChecked ? _onConfirm : null,
        ),
        SizedBox(height: LayoutConstants.space2),
        OutlineButton(
          onTap: () => context.pop(),
          text: 'Cancel',
        ),
      ],
    );
  }
}
