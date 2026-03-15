import 'dart:async';

import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:app/app/providers/local_data_cleanup_provider.dart';
import 'package:app/app/providers/package_info_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/ui/settings_dialog_helper.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/buttons/outline_button.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Settings page (Account page) with Rebuild Metadata and Forget I exist.
/// Copied from old Feral File app; Preference removed, Data Management
/// replaced with two direct options per plan.
class SettingsPage extends ConsumerWidget {
  /// Creates a [SettingsPage].
  const SettingsPage({super.key});

  Future<void> _showRebuildMetadataDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await UIHelper.showDialog<void>(
      context,
      'Rebuild metadata',
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This action will safely clear local cache and\n'
            're-download all artwork metadata. We recommend only doing this '
            'if instructed to do so by customer support to resolve a problem.',
            style: AppTypography.body(context).copyWith(
              color: PrimitivesTokens.colorsWhite,
            ),
          ),
          SizedBox(height: LayoutConstants.space10),
          PrimaryButton(
            text: 'Rebuild',
            onTap: () async {
              final router = GoRouter.of(context);
              final overlayNotifier = ref.read(appOverlayProvider.notifier);
              final cleanupService = ref.read(localDataCleanupServiceProvider);

              context.pop();
              router.go(Routes.home);

              final toastOverlayId = overlayNotifier.showToast(
                message: 'Cleaning metadata...',
              );
              await WidgetsBinding.instance.endOfFrame;

              try {
                await cleanupService.rebuildMetadata();
              } finally {
                overlayNotifier.dismissOverlay(toastOverlayId);
              }
            },
          ),
          SizedBox(height: LayoutConstants.space2),
          OutlineButton(
            onTap: () => context.pop(),
            text: 'Cancel',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final systemBackground = isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final systemLabel = isDarkMode
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF000000);
    final systemSecondary = isDarkMode
        ? const Color(0xFF8E8E93)
        : const Color(0xFF6D6D72);
    final systemSeparator = isDarkMode
        ? const Color(0xFF38383A)
        : const Color(0xFFD1D1D6);

    return Scaffold(
      backgroundColor: systemBackground,
      appBar: SetupAppBar(
        title: 'Settings',
        titleStyle: AppTypography.h4(context).copyWith(color: systemLabel),
        backgroundColor: systemBackground,
        titleColor: systemLabel,
        isDarkMode: isDarkMode,
        withDivider: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: LayoutConstants.space8),
            // Rebuild metadata row
            _SettingRow(
              title: 'Rebuild metadata',
              subtitle:
                  'Clear local cache and re-download all artwork metadata.',
              titleColor: systemLabel,
              subtitleColor: systemSecondary,
              trailingColor: systemSecondary,
              onTap: () {
                unawaited(_showRebuildMetadataDialog(context, ref));
              },
            ),
            Divider(
              height: 1,
              color: systemSeparator,
            ),
            // Forget I exist row
            _SettingRow(
              title: 'Forget I exist',
              subtitle:
                  'Erase all information about me and delete my keys from my cloud backup.',
              titleColor: systemLabel,
              subtitleColor: systemSecondary,
              trailingColor: systemSecondary,
              onTap: () {
                unawaited(
                  SettingsDialogHelper.showForgetExistDialog(context, ref),
                );
              },
            ),
            const Spacer(),
            // Version section at bottom
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: LayoutConstants.pageHorizontalDefault,
                vertical: LayoutConstants.space6,
              ),
              child: _VersionSection(
                packageInfoAsync: ref.watch(packageInfoProvider),
                textColor: systemSecondary,
                outlineColor: systemSeparator,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single settings row with title, optional subtitle, and chevron.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
    required this.trailingColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;
  final Color trailingColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: LayoutConstants.pageHorizontalDefault,
        vertical: LayoutConstants.space2,
      ),
      title: Text(
        title,
        style: AppTypography.h4(context).copyWith(
          color: titleColor,
        ),
      ),
      subtitle: Padding(
        padding: EdgeInsets.only(top: LayoutConstants.space1),
        child: Text(
          subtitle,
          style: AppTypography.body(context).copyWith(
            color: subtitleColor,
          ),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: trailingColor,
      ),
      onTap: onTap,
    );
  }
}

/// Version info section: EULA, Privacy Policy links, version badge, up-to-date.
class _VersionSection extends StatelessWidget {
  const _VersionSection({
    required this.packageInfoAsync,
    required this.textColor,
    required this.outlineColor,
  });

  final AsyncValue<PackageInfo> packageInfoAsync;
  final Color textColor;
  final Color outlineColor;

  @override
  Widget build(BuildContext context) {
    final packageInfo = packageInfoAsync.value;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => context.push(Routes.settingsEula),
              child: Text(
                'EULA',
                style: AppTypography.body(context).copyWith(
                  color: textColor,
                  decoration: TextDecoration.underline,
                  decorationColor: textColor,
                ),
              ),
            ),
            Text(
              ' and ',
              style: AppTypography.body(context).copyWith(
                color: textColor,
              ),
            ),
            GestureDetector(
              onTap: () => context.push(Routes.settingsPrivacy),
              child: Text(
                'Privacy Policy',
                style: AppTypography.body(context).copyWith(
                  color: textColor,
                  decoration: TextDecoration.underline,
                  decorationColor: textColor,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: LayoutConstants.space6),
        if (packageInfo != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: outlineColor),
            ),
            child: Text(
              'v.${packageInfo.version}(${packageInfo.buildNumber})',
              key: const Key('version'),
              style: AppTypography.body(context).copyWith(
                color: textColor,
              ),
            ),
          ),
        SizedBox(height: LayoutConstants.space2),
        Text(
          'Good! You are up to date!',
          style: AppTypography.body(context).copyWith(
            color: textColor,
          ),
        ),
      ],
    );
  }
}
