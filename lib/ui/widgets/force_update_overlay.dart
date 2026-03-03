import 'package:app/app/providers/force_update_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/domain/models/version_info.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen overlay with bottom modal shown when force update is required.
///
/// UI matches old Feral File app: title, body text, single Update button.
/// User cannot pop or dismiss.
class ForceUpdateOverlay extends ConsumerWidget {
  /// Creates a [ForceUpdateOverlay].
  const ForceUpdateOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionInfo = ref.watch(forceUpdateProvider);

    if (versionInfo == null) {
      return const SizedBox.shrink();
    }

    return PopScope(
      canPop: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.5),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: _ForceUpdateDialogContent(
                versionInfo: versionInfo,
                onUpdate: () => ref
                    .read(forceUpdateServiceProvider)
                    .openStoreUrl(versionInfo.link),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Content matches old repo: UIHelper.showDialog + Column with body + Update.
class _ForceUpdateDialogContent extends StatelessWidget {
  const _ForceUpdateDialogContent({
    required this.versionInfo,
    required this.onUpdate,
  });

  final VersionInfo versionInfo;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 32),
      decoration: const BoxDecoration(
        color: AppColor.auGreyBackground,
        borderRadius: BorderRadius.only(topRight: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update Required',
            style: AppTypography.h2(context).white,
          ),
          const SizedBox(height: 40),
          Text(
            'There is a newer version available for download! Please update the app to continue.',
            style: AppTypography.body(context).white,
          ),
          const SizedBox(height: 35),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: 'Update',
                  onTap: onUpdate,
                  color: AppColor.feralFileLightBlue,
                  textColor: AppColor.primaryBlack,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
