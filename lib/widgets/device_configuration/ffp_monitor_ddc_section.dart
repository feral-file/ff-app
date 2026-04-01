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
    final err = status.errors;
    final showBrightness = err?.containsKey('brightness') != true;
    final showContrast = err?.containsKey('contrast') != true;
    final showVol = err?.containsKey('volume') != true;
    final showPowerControl = err?.containsKey('power') != true;

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
                    color: _powerDotColor(status.power),
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

  /// The two modes not currently active (on=green, off=red, standby=yellow).
  List<({String wire, Color color})> _otherPowerModes(String? powerRaw) {
    final c = _normalizePowerKey(powerRaw);
    const all = <({String wire, Color color})>[
      (wire: 'on', color: Colors.green),
      (wire: 'off', color: Colors.red),
      (wire: 'standby', color: Colors.amber),
    ];
    if (c == null) {
      return [
        (wire: 'on', color: Colors.green),
        (wire: 'off', color: Colors.red),
      ];
    }
    return all.where((m) => m.wire != c).toList();
  }

  /// Puts the power-off action at index 1 so it is always the second control.
  List<({String wire, Color color})> _powerModesWithOffSecond(
    List<({String wire, Color color})> modes,
  ) {
    if (modes.length < 2) {
      return modes;
    }
    final offIndex = modes.indexWhere((m) => m.wire == 'off');
    if (offIndex < 0) {
      return modes;
    }
    if (offIndex == 1) {
      return modes;
    }
    final off = modes[offIndex];
    final rest = List<({String wire, Color color})>.from(modes)..removeAt(offIndex);
    return [rest.first, off, ...rest.sublist(1)];
  }

  IconData _powerModeIcon(String _) {
    return Icons.power_settings_new;
  }

  String _powerModeSemanticLabel(String wire) {
    switch (wire) {
      case 'on':
        return 'On';
      case 'off':
        return 'Off';
      case 'standby':
        return 'Standby';
      default:
        return 'Power';
    }
  }

  String? _normalizePowerKey(String? p) {
    switch (p?.trim().toLowerCase()) {
      case 'on':
      case 'poweron':
        return 'on';
      case 'off':
      case 'poweroff':
        return 'off';
      case 'standby':
      case 'suspend':
        return 'standby';
      default:
        return null;
    }
  }

  List<Widget> _otherPowerModeButtons(
    BuildContext context,
    FF1FfpDdcControlNotifier notifier,
    FfpDdcPanelStatus status,
  ) {
    return _powerModesWithOffSecond(_otherPowerModes(status.power))
        .map(
          (m) => Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Semantics(
              button: true,
              label: _powerModeSemanticLabel(m.wire),
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
                    await notifier.setPower(m.wire);
                  } on Exception {
                    // The provider owns rollback and reconciliation.
                  }
                },
                icon: Icon(
                  _powerModeIcon(m.wire),
                  color: m.color,
                  size: 24,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  Color _powerDotColor(String? p) {
    switch (p?.trim().toLowerCase()) {
      case 'on':
      case 'poweron':
        return Colors.green;
      case 'off':
      case 'poweroff':
        return Colors.red;
      case 'standby':
      case 'suspend':
        return Colors.amber;
      case null:
      case '':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _powerLabel(String? p) {
    switch (p?.trim().toLowerCase()) {
      case 'on':
      case 'poweron':
        return 'On';
      case 'off':
      case 'poweroff':
        return 'Off';
      case 'standby':
      case 'suspend':
        return 'Standby';
      case null:
      case '':
        return 'Unknown';
      default:
        return p ?? 'Unknown';
    }
  }
}
