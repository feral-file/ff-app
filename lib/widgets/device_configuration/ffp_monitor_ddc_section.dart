import 'package:app/app/providers/ff1_control_surface_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1/ffp_ddc_command_errors.dart';
import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/device_configuration/device_info_box.dart';
import 'package:app/widgets/device_configuration/ffp_slider_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// FFP display / DDC monitor controls (not FF1 system audio).
class FfpMonitorDdcSection extends ConsumerWidget {
  /// Creates the FFP monitor section.
  const FfpMonitorDdcSection({
    required this.topicId,
    required this.isConnected,
    required this.isControllable,
    super.key,
  });

  /// Relayer topic id for FFP DDC commands.
  final String topicId;

  /// When false, section does not render controls.
  final bool isConnected;

  /// When false, sliders are disabled (same gating as other device actions).
  final bool isControllable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isConnected || topicId.isEmpty) {
      return const SizedBox.shrink();
    }

    final status = ref.watch(ff1FfpDdcControlProvider(topicId));
    if (!status.hasData) {
      return const SizedBox.shrink();
    }

    return _statusContent(context, ref, status);
  }

  Widget _statusContent(
    BuildContext context,
    WidgetRef ref,
    FfpDdcPanelStatus status,
  ) {
    final showBrightness = status.brightness != null;
    final showContrast = status.contrast != null;
    final showVol = status.volume != null;
    final showPowerControl = status.power != null;

    final name = status.monitor?.trim().isNotEmpty ?? false
        ? status.monitor!.trim()
        : 'Display';
    final power = _powerLabel(status.power);
    final enable = isControllable;
    final notifier = ref.read(ff1FfpDdcControlProvider(topicId).notifier);

    const divider = Divider(
      height: 16,
      color: AppColor.auGreyBackground,
      thickness: 1,
    );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColor.primaryBlack,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeviceInfoItem(
            title: 'Monitor',
            child: Text(
              name,
              style: AppTypography.body(context).white,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          divider,
          DeviceInfoItem(
            title: 'Power',
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color:
                        status.power?.monitorPowerAccentColor ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    power,
                    style: AppTypography.body(context).white,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showPowerControl && enable)
                  ..._otherPowerModeButtons(context, notifier, status),
              ],
            ),
          ),
          if (showBrightness) ...[
            SizedBox(height: LayoutConstants.space4),
            FfpBrightnessControl(
              key: const ValueKey('ffp_brightness_slider'),
              value: (status.brightness ?? 0).toDouble(),
              enabled: enable,
              onChanged: notifier.setBrightnessDraft,
              onChangeEnd: (v) async {
                try {
                  await notifier.commitBrightness(v);
                } on FfpDdcUnsupportedException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.message)),
                    );
                  }
                } on Exception {
                  // The provider owns rollback and reconciliation.
                }
              },
            ),
          ],
          if (showContrast) ...[
            SizedBox(height: LayoutConstants.space4),
            FfpContrastControl(
              key: const ValueKey('ffp_contrast_slider'),
              value: (status.contrast ?? 0).toDouble(),
              enabled: enable,
              onChanged: notifier.setContrastDraft,
              onChangeEnd: (v) async {
                try {
                  await notifier.commitContrast(v);
                } on Exception {
                  // The provider owns rollback and reconciliation.
                }
              },
            ),
          ],
          if (showVol) ...[
            SizedBox(height: LayoutConstants.space4),
            FfpMonitorVolumeControl(
              key: const ValueKey('ffp_monitor_volume_slider'),
              value: (status.volume ?? 0).toDouble(),
              enabled: enable && showVol,
              iconEnabled: enable,
              onChanged: notifier.setVolumeDraft,
              onChangeEnd: (v) async {
                try {
                  await notifier.commitVolume(v);
                } on Exception {
                  // The provider owns rollback and reconciliation.
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  /// The two modes not currently active.
  List<FfpDdcPanelPower> _otherPowerModes(FfpDdcPanelPower? current) {
    const all = FfpDdcPanelPower.values;
    if (current == null) {
      return [FfpDdcPanelPower.on, FfpDdcPanelPower.off];
    }
    return all.where((m) => m != current).toList();
  }

  /// Puts the power-off action at index 1 so it is always the second control.
  List<FfpDdcPanelPower> _powerModesWithOffSecond(
    List<FfpDdcPanelPower> modes,
  ) {
    if (modes.length < 2) {
      return modes;
    }
    final offIndex = modes.indexWhere((m) => m == FfpDdcPanelPower.off);
    if (offIndex < 0) {
      return modes;
    }
    if (offIndex == 1) {
      return modes;
    }
    final off = modes[offIndex];
    final rest = List<FfpDdcPanelPower>.from(modes)..removeAt(offIndex);
    return [rest.first, off, ...rest.sublist(1)];
  }

  IconData _powerModeIcon(FfpDdcPanelPower _) {
    return Icons.power_settings_new;
  }

  String _powerModeSemanticLabel(FfpDdcPanelPower mode) {
    switch (mode) {
      case FfpDdcPanelPower.on:
        return 'On';
      case FfpDdcPanelPower.off:
        return 'Off';
      case FfpDdcPanelPower.standby:
        return 'Standby';
    }
  }

  List<Widget> _otherPowerModeButtons(
    BuildContext context,
    FF1FfpDdcControlNotifier notifier,
    FfpDdcPanelStatus status,
  ) {
    return _powerModesWithOffSecond(_otherPowerModes(status.power))
        .map(
          (mode) => Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Semantics(
              button: true,
              label: _powerModeSemanticLabel(mode),
              child: IconButton(
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  minimumSize: const Size(44, 44),
                  maximumSize: const Size(44, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  try {
                    await notifier.setPower(mode);
                  } on Exception {
                    // The provider owns rollback and reconciliation.
                  }
                },
                icon: Icon(
                  _powerModeIcon(mode),
                  color: mode.monitorPowerAccentColor,
                  size: 24,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  String _powerLabel(FfpDdcPanelPower? p) {
    switch (p) {
      case FfpDdcPanelPower.on:
        return 'On';
      case FfpDdcPanelPower.off:
        return 'Off';
      case FfpDdcPanelPower.standby:
        return 'Standby';
      case null:
        return 'Unknown';
    }
  }
}

/// UI accent for this section (domain [FfpDdcPanelPower] stays Flutter-free).
extension FfpDdcPanelPowerMonitorUi on FfpDdcPanelPower {
  /// Color for the status dot and mode switch icons.
  Color get monitorPowerAccentColor {
    switch (this) {
      case FfpDdcPanelPower.on:
        return Colors.green;
      case FfpDdcPanelPower.off:
        return Colors.red;
      case FfpDdcPanelPower.standby:
        return Colors.amber;
    }
  }
}
