import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1/ffp_ddc_command_errors.dart';
import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/device_configuration/labeled_slider_control.dart';
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
  /// Local slider values while dragging or after optimistic set.
  final Map<String, Map<String, double>> _optimistic = {};

  double _sliderValue(
    FfpDdcMonitorPanel panel,
    String key,
    int? serverPercent,
  ) {
    final mid = panel.monitorId;
    final local = _optimistic[mid]?[key];
    if (local != null) {
      return local;
    }
    return (serverPercent ?? 0).toDouble();
  }

  void _setOptimistic(String monitorId, String key, double v) {
    setState(() {
      _optimistic.putIfAbsent(monitorId, () => {});
      _optimistic[monitorId]![key] = v;
    });
  }

  void _clearOptimisticKey(String monitorId, String key) {
    setState(() {
      _optimistic[monitorId]?.remove(key);
      if (_optimistic[monitorId]?.isEmpty ?? false) {
        _optimistic.remove(monitorId);
      }
    });
  }

  Future<void> _runBrightness(
    FfpDdcMonitorPanel panel,
    double v,
  ) async {
    final control = ref.read(ff1WifiControlProvider);
    final mid = panel.monitorId;
    final prev = _optimistic[mid]?['brightness'];
    _setOptimistic(mid, 'brightness', v);
    try {
      await control.setFfpMonitorBrightness(
        topicId: widget.topicId,
        monitorId: mid,
        percent: v.round(),
      );
      _clearOptimisticKey(mid, 'brightness');
    } on FfpDdcUnsupportedException catch (e) {
      _log.info('Brightness unsupported: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      if (prev != null) {
        _setOptimistic(mid, 'brightness', prev);
      } else {
        _clearOptimisticKey(mid, 'brightness');
      }
    } on Exception catch (e) {
      _log.warning('setFfpMonitorBrightness: $e');
      if (prev != null) {
        _setOptimistic(mid, 'brightness', prev);
      } else {
        _clearOptimisticKey(mid, 'brightness');
      }
    }
  }

  Future<void> _runContrast(FfpDdcMonitorPanel panel, double v) async {
    final control = ref.read(ff1WifiControlProvider);
    final mid = panel.monitorId;
    final prev = _optimistic[mid]?['contrast'];
    _setOptimistic(mid, 'contrast', v);
    try {
      await control.setFfpMonitorContrast(
        topicId: widget.topicId,
        monitorId: mid,
        percent: v.round(),
      );
      _clearOptimisticKey(mid, 'contrast');
    } on Exception catch (e) {
      _log.warning('setFfpMonitorContrast: $e');
      if (prev != null) {
        _setOptimistic(mid, 'contrast', prev);
      } else {
        _clearOptimisticKey(mid, 'contrast');
      }
    }
  }

  Future<void> _runMonitorVolume(FfpDdcMonitorPanel panel, double v) async {
    final control = ref.read(ff1WifiControlProvider);
    final mid = panel.monitorId;
    final prev = _optimistic[mid]?['monitorVolume'];
    _setOptimistic(mid, 'monitorVolume', v);
    try {
      await control.setFfpMonitorVolume(
        topicId: widget.topicId,
        monitorId: mid,
        percent: v.round(),
      );
      _clearOptimisticKey(mid, 'monitorVolume');
    } on Exception catch (e) {
      _log.warning('setFfpMonitorVolume: $e');
      if (prev != null) {
        _setOptimistic(mid, 'monitorVolume', prev);
      } else {
        _clearOptimisticKey(mid, 'monitorVolume');
      }
    }
  }

  Future<void> _toggleMute(FfpDdcMonitorPanel panel) async {
    final control = ref.read(ff1WifiControlProvider);
    final mid = panel.monitorId;
    final next = !(panel.isMuted ?? false);
    try {
      await control.setFfpMonitorMute(
        topicId: widget.topicId,
        monitorId: mid,
        muted: next,
      );
    } on Exception catch (e) {
      _log.warning('setFfpMonitorMute: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isConnected || widget.topicId.isEmpty) {
      return const SizedBox.shrink();
    }

    final async = ref.watch(ff1FfpDdcPanelStatusStreamProvider(widget.topicId));

    return async.when(
      data: (status) {
        if (status.panels.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Display (FFP)',
              style: AppTypography.body(context).white,
            ),
            SizedBox(height: LayoutConstants.space2),
            Text(
              'Monitor brightness and volume here apply to the connected '
              'display. FF1 audio is controlled in Audio above.',
              style: AppTypography.caption(context).white,
            ),
            SizedBox(height: LayoutConstants.space4),
            for (final panel in status.panels) _panel(context, panel),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) {
        _log.fine('Ffp DDC panel status unavailable: $e');
        return const SizedBox.shrink();
      },
    );
  }

  Widget _panel(BuildContext context, FfpDdcMonitorPanel panel) {
    final name = panel.displayName?.trim().isNotEmpty ?? false
        ? panel.displayName!
        : panel.monitorId;
    final power = _powerLabel(panel.powerState);
    final enable = widget.isControllable;

    final showBrightness = panel.capabilities.brightnessSupported != false;
    final showContrast = panel.capabilities.contrastSupported != false;
    final showVol = panel.capabilities.volumeSupported != false;
    final showMute = panel.capabilities.muteSupported != false;

    return Padding(
      padding: EdgeInsets.only(bottom: LayoutConstants.space6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monitor: $name',
            style: AppTypography.body(context).white,
          ),
          SizedBox(height: LayoutConstants.space2),
          Text(
            'Power: $power',
            style: AppTypography.caption(context).white,
          ),
          SizedBox(height: LayoutConstants.space4),
          if (showBrightness) ...[
            LabeledSliderControl(
              label: 'Brightness',
              value: _sliderValue(panel, 'brightness', panel.brightnessPercent),
              enabled: enable,
              onChanged: (v) =>
                  _setOptimistic(panel.monitorId, 'brightness', v),
              onChangeEnd: (v) => _runBrightness(panel, v),
            ),
            SizedBox(height: LayoutConstants.space4),
          ],
          if (showContrast) ...[
            LabeledSliderControl(
              label: 'Contrast',
              value: _sliderValue(panel, 'contrast', panel.contrastPercent),
              enabled: enable,
              onChanged: (v) => _setOptimistic(panel.monitorId, 'contrast', v),
              onChangeEnd: (v) => _runContrast(panel, v),
            ),
            SizedBox(height: LayoutConstants.space4),
          ],
          if (showVol || showMute)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showMute)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: IconButton(
                      onPressed: enable ? () => _toggleMute(panel) : null,
                      icon: Icon(
                        (panel.isMuted ?? false)
                            ? Icons.volume_off
                            : Icons.volume_up,
                        color: enable
                            ? AppColor.white
                            : AppColor.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                if (showVol)
                  Expanded(
                    child: LabeledSliderControl(
                      label: 'Monitor volume',
                      value: _sliderValue(
                        panel,
                        'monitorVolume',
                        panel.monitorVolumePercent,
                      ),
                      enabled: enable,
                      onChanged: (v) => _setOptimistic(
                        panel.monitorId,
                        'monitorVolume',
                        v,
                      ),
                      onChangeEnd: (v) => _runMonitorVolume(panel, v),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _powerLabel(FfpDdcPowerState? p) {
    switch (p) {
      case FfpDdcPowerState.on:
        return 'On';
      case FfpDdcPowerState.off:
        return 'Off';
      case FfpDdcPowerState.standby:
        return 'Standby';
      case null:
        return 'Unknown';
    }
  }
}
