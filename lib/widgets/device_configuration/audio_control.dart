import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/widgets/device_configuration/zero_toggle_icon_slider_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('AudioControl');

/// Audio control: volume slider and mute toggle for an FF1 device.
///
/// Local state is initialised once from [ff1CurrentDeviceStatusProvider] —
/// either immediately in `initState` (if a status is already available) or on
/// the first emission via `ref.listen`. After that, device-status updates are
/// intentionally ignored to avoid overwriting in-flight user changes.
///
/// All interactions (mute toggle, volume drag) update local state immediately
/// for instant feedback, then send the command to the device. On failure the
/// value is reverted to the last confirmed state.
class AudioControl extends ConsumerStatefulWidget {
  /// Constructor.
  const AudioControl({
    required this.topicId,
    super.key,
    this.isEnable = true,
    this.gap,
    this.iconSize,
  });

  /// Device topic ID used to route commands.
  final String topicId;

  /// Whether the controls are interactive. Disabled controls are rendered at
  /// reduced opacity and ignore taps/drags.
  final bool isEnable;

  /// Padding for the audio control.
  final double? gap;

  /// Icon size.
  final double? iconSize;

  @override
  ConsumerState<AudioControl> createState() => _AudioControlState();
}

class _AudioControlState extends ConsumerState<AudioControl> {
  /// Optimistic volume shown in the slider (0–100).
  double _volume = 50;

  /// True once local state has been seeded from device status.
  bool _syncedFromDevice = false;

  @override
  void initState() {
    super.initState();
    // Seed local state from whatever status is already in the provider cache.
    // If the stream hasn't emitted yet this is null and we fall back to the
    // ref.listen in build().
    _applyDeviceStatus(ref.read(ff1CurrentDeviceStatusProvider));
  }

  /// Commits a volume change and reverts on command failure.
  Future<void> _onVolumeChangeEnd(double v) async {
    final prevVolume = _volume;
    final control = ref.read(ff1WifiControlProvider);

    try {
      await control.setVolume(topicId: widget.topicId, percent: v.round());
    } on Exception catch (e) {
      setState(() {
        _volume = prevVolume;
      });
      _log.warning('Error setting volume: $e');
    }
  }

  /// Seeds [_volume] from [status].
  ///
  /// No-op if [status] is null or we have already synced.
  void _applyDeviceStatus(FF1DeviceStatus? status) {
    if (status == null || _syncedFromDevice) return;
    _volume = status.volume?.toDouble() ?? _volume;
    _syncedFromDevice = true;
  }

  @override
  Widget build(BuildContext context) {
    // Catch the first device-status emission when it wasn't ready at initState.
    ref.listen<FF1DeviceStatus?>(ff1CurrentDeviceStatusProvider, (_, next) {
      if (!_syncedFromDevice) {
        setState(() => _applyDeviceStatus(next));
      }
    });

    return ZeroToggleIconSliderControl(
      iconAsset: 'assets/images/icon_volume.svg',
      zeroIconAsset: 'assets/images/icon_volume_muted.svg',
      semanticLabel: 'Volume',
      enabled: widget.isEnable,
      iconSize: widget.iconSize ?? 18,
      gap: widget.gap ?? LayoutConstants.space2,
      value: _volume,
      onChanged: (v) => setState(() => _volume = v),
      onChangeEnd: _onVolumeChangeEnd,
    );
  }
}
