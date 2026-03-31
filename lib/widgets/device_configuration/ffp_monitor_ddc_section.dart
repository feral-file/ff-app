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
  final Map<String, double> _optimistic = {};
  FfpDdcPanelStatus? _lastStatus;

  String _monitorId(FfpDdcPanelStatus s) =>
      s.monitor?.trim().isNotEmpty ?? false ? s.monitor!.trim() : 'default';

  double _sliderValue(String key, int? serverPercent) {
    final local = _optimistic[key];
    if (local != null) {
      return local;
    }
    return (serverPercent ?? 0).toDouble();
  }

  void _setOptimistic(String key, double v) {
    if (!mounted) {
      return;
    }
    setState(() {
      _optimistic[key] = v;
    });
  }

  void _clearOptimisticKey(String key) {
    if (!mounted) {
      return;
    }
    setState(() {
      _optimistic.remove(key);
    });
  }

  Future<void> _runBrightness(FfpDdcPanelStatus s, double v) async {
    final control = ref.read(ff1WifiControlProvider);
    final mid = _monitorId(s);
    final prev = _optimistic['brightness'];
    _setOptimistic('brightness', v);
    try {
      await control.setFfpMonitorBrightness(
        topicId: widget.topicId,
        monitorId: mid,
        percent: v.round(),
      );
      _clearOptimisticKey('brightness');
    } on FfpDdcUnsupportedException catch (e) {
      _log.info('Brightness unsupported: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      if (prev != null) {
        _setOptimistic('brightness', prev);
      } else {
        _clearOptimisticKey('brightness');
      }
    } on Exception catch (e) {
      _log.warning('setFfpMonitorBrightness: $e');
      if (prev != null) {
        _setOptimistic('brightness', prev);
      } else {
        _clearOptimisticKey('brightness');
      }
    }
  }

  Future<void> _runContrast(FfpDdcPanelStatus s, double v) async {
    final control = ref.read(ff1WifiControlProvider);
    final mid = _monitorId(s);
    final prev = _optimistic['contrast'];
    _setOptimistic('contrast', v);
    try {
      await control.setFfpMonitorContrast(
        topicId: widget.topicId,
        monitorId: mid,
        percent: v.round(),
      );
      _clearOptimisticKey('contrast');
    } on Exception catch (e) {
      _log.warning('setFfpMonitorContrast: $e');
      if (prev != null) {
        _setOptimistic('contrast', prev);
      } else {
        _clearOptimisticKey('contrast');
      }
    }
  }

  Future<void> _runMonitorVolume(FfpDdcPanelStatus s, double v) async {
    final control = ref.read(ff1WifiControlProvider);
    final mid = _monitorId(s);
    final prev = _optimistic['monitorVolume'];
    _setOptimistic('monitorVolume', v);
    try {
      await control.setFfpMonitorVolume(
        topicId: widget.topicId,
        monitorId: mid,
        percent: v.round(),
      );
      _clearOptimisticKey('monitorVolume');
    } on Exception catch (e) {
      _log.warning('setFfpMonitorVolume: $e');
      if (prev != null) {
        _setOptimistic('monitorVolume', prev);
      } else {
        _clearOptimisticKey('monitorVolume');
      }
    }
  }

  Future<void> _toggleMute(FfpDdcPanelStatus s) async {
    final control = ref.read(ff1WifiControlProvider);
    final mid = _monitorId(s);
    final next = !(s.mute ?? false);
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
        _lastStatus = status;
        if (!status.hasData) {
          return const SizedBox.shrink();
        }
        return _statusContent(context, status);
      },
      loading: () => _lastStatus == null || !_lastStatus!.hasData
          ? const SizedBox.shrink()
          : _statusContent(context, _lastStatus!),
      error: (e, _) {
        _log.fine('Ffp DDC panel status unavailable: $e');
        return _lastStatus == null || !_lastStatus!.hasData
            ? const SizedBox.shrink()
            : _statusContent(context, _lastStatus!);
      },
    );
  }

  Widget _statusContent(BuildContext context, FfpDdcPanelStatus status) {
    final err = status.errors;
    final showBrightness = err?.containsKey('brightness') != true;
    final showContrast = err?.containsKey('contrast') != true;
    final showVol = err?.containsKey('volume') != true;
    final showMute = err?.containsKey('mute') != true;

    final name = status.monitor?.trim().isNotEmpty ?? false
        ? status.monitor!.trim()
        : 'Display';
    final power = _powerLabel(status.power);
    final enable = widget.isControllable;

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
        Padding(
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
                  value: _sliderValue('brightness', status.brightness),
                  enabled: enable,
                  onChanged: (v) => _setOptimistic('brightness', v),
                  onChangeEnd: (v) => _runBrightness(status, v),
                ),
                SizedBox(height: LayoutConstants.space4),
              ],
              if (showContrast) ...[
                LabeledSliderControl(
                  label: 'Contrast',
                  value: _sliderValue('contrast', status.contrast),
                  enabled: enable,
                  onChanged: (v) => _setOptimistic('contrast', v),
                  onChangeEnd: (v) => _runContrast(status, v),
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
                          onPressed: enable ? () => _toggleMute(status) : null,
                          icon: Icon(
                            (status.mute ?? false)
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
                            'monitorVolume',
                            status.volume,
                          ),
                          enabled: enable,
                          onChanged: (v) =>
                              _setOptimistic('monitorVolume', v),
                          onChangeEnd: (v) => _runMonitorVolume(status, v),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
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
