import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1/ffp_ddc_command_errors.dart';
import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/device_configuration/ffp_slider_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('FfpMonitorDdcSection');

/// FFP display / DDC monitor controls (not FF1 system audio).
class FfpMonitorDdcSection extends ConsumerStatefulWidget {
  /// Creates the FFP monitor section.
  const FfpMonitorDdcSection({
    required this.topicId,
    required this.isConnected,
    required this.isControllable,
    super.key,
  });

  /// Relayer topic id for FFP DDC commands.
  final String topicId;

  /// When false, section does not poll or render controls.
  final bool isConnected;

  /// When false, sliders are disabled (same gating as other device actions).
  final bool isControllable;

  @override
  ConsumerState<FfpMonitorDdcSection> createState() =>
      _FfpMonitorDdcSectionState();
}

class _FfpMonitorDdcSectionState extends ConsumerState<FfpMonitorDdcSection> {
  FfpDdcPanelStatus? _status;
  bool _syncedFromDevice = false;

  String _monitorId(FfpDdcPanelStatus s) =>
      s.monitor?.trim().isNotEmpty ?? false ? s.monitor!.trim() : 'default';

  void _applyDeviceStatus(FfpDdcPanelStatus? status) {
    if (status == null || !status.hasData || _syncedFromDevice) {
      return;
    }
    _status = status;
    _syncedFromDevice = true;
  }

  void _setStatus(FfpDdcPanelStatus status) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
    });
  }

  Future<void> _runBrightness(FfpDdcPanelStatus s, double v) async {
    final control = ref.read(ff1WifiControlProvider);
    final mid = _monitorId(s);
    final prev = _status ?? s;
    _setStatus(prev.copyWith(brightness: v.round()));
    try {
      await control.setFfpMonitorBrightness(
        topicId: widget.topicId,
        monitorId: mid,
        percent: v.round(),
      );
    } on FfpDdcUnsupportedException catch (e) {
      _log.info('Brightness unsupported: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      _setStatus(prev);
    } on Exception catch (e) {
      _log.warning('setFfpMonitorBrightness: $e');
      _setStatus(prev);
    }
  }

  Future<void> _runContrast(FfpDdcPanelStatus s, double v) async {
    final control = ref.read(ff1WifiControlProvider);
    final mid = _monitorId(s);
    final prev = _status ?? s;
    _setStatus(prev.copyWith(contrast: v.round()));
    try {
      await control.setFfpMonitorContrast(
        topicId: widget.topicId,
        monitorId: mid,
        percent: v.round(),
      );
    } on Exception catch (e) {
      _log.warning('setFfpMonitorContrast: $e');
      _setStatus(prev);
    }
  }

  Future<void> _runMonitorVolume(FfpDdcPanelStatus s, double v) async {
    final control = ref.read(ff1WifiControlProvider);
    final mid = _monitorId(s);
    final prev = _status ?? s;
    _setStatus(prev.copyWith(volume: v.round()));
    try {
      await control.setFfpMonitorVolume(
        topicId: widget.topicId,
        monitorId: mid,
        percent: v.round(),
      );
    } on Exception catch (e) {
      _log.warning('setFfpMonitorVolume: $e');
      _setStatus(prev);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isConnected || widget.topicId.isEmpty) {
      return const SizedBox.shrink();
    }

    final statusProvider = ff1FfpDdcPanelStatusStreamProvider(widget.topicId);
    ref.listen<AsyncValue<FfpDdcPanelStatus>>(statusProvider, (_, next) {
      next.whenData((status) {
        if (!_syncedFromDevice) {
          setState(() => _applyDeviceStatus(status));
        }
      });
    });
    final async = ref.watch(statusProvider);

    return async.when(
      data: (status) {
        final display = _status ?? status;
        if (!display.hasData) {
          return const SizedBox.shrink();
        }
        return _statusContent(context, display);
      },
      loading: () => _status == null || !_status!.hasData
          ? const SizedBox.shrink()
          : _statusContent(context, _status!),
      error: (e, _) {
        _log.fine('Ffp DDC panel status unavailable: $e');
        return _status == null || !_status!.hasData
            ? const SizedBox.shrink()
            : _statusContent(context, _status!);
      },
    );
  }

  Widget _statusContent(BuildContext context, FfpDdcPanelStatus status) {
    final err = status.errors;
    final showBrightness = err?.containsKey('brightness') != true;
    final showContrast = err?.containsKey('contrast') != true;
    final showVol = err?.containsKey('volume') != true;

    final name = status.monitor?.trim().isNotEmpty ?? false
        ? status.monitor!.trim()
        : 'Display';
    final power = _powerLabel(status.power);
    final enable = widget.isControllable;

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
          _KeyValueRow(
            title: 'Monitor:',
            child: Text(
              name,
              style: AppTypography.body(context).white,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          divider,
          _KeyValueRow(
            title: 'Power:',
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
              ],
            ),
          ),
          if (showBrightness) ...[
            SizedBox(height: LayoutConstants.space4),
            FfpBrightnessControl(
              key: const ValueKey('ffp_brightness_slider'),
              value: (status.brightness ?? 0).toDouble(),
              enabled: enable,
              onChanged: (v) =>
                  _setStatus(status.copyWith(brightness: v.round())),
              onChangeEnd: (v) => _runBrightness(status, v),
            ),
          ],
          if (showContrast) ...[
            SizedBox(height: LayoutConstants.space4),
            FfpContrastControl(
              key: const ValueKey('ffp_contrast_slider'),
              value: (status.contrast ?? 0).toDouble(),
              enabled: enable,
              onChanged: (v) =>
                  _setStatus(status.copyWith(contrast: v.round())),
              onChangeEnd: (v) => _runContrast(status, v),
            ),
          ],
          if (showVol) ...[
            SizedBox(height: LayoutConstants.space4),
            FfpMonitorVolumeControl(
              key: const ValueKey('ffp_monitor_volume_slider'),
              value: (status.volume ?? 0).toDouble(),
              enabled: enable && showVol,
              iconEnabled: enable,
              onChanged: (v) =>
                  _setStatus(status.copyWith(volume: v.round())),
              onChangeEnd: (v) => _runMonitorVolume(status, v),
            ),
          ],
        ],
      ),
    );
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
        return Colors.grey;
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

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.body(context).grey,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: child,
          ),
        ),
      ],
    );
  }
}
