import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('AudioControl');

/// Audio control: volume slider and mute toggle for an FF1 device.
///
/// Local state is initialised once from [ff1CurrentDeviceStatusProvider] —
/// either immediately in [initState] (if a status is already available) or on
/// the first emission via [ref.listen]. After that, device-status updates are
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

  /// Optimistic mute flag shown on the icon.
  bool _isMuted = false;

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

  /// Seeds [_volume] / [_isMuted] from [status].
  ///
  /// No-op if [status] is null or we have already synced.
  void _applyDeviceStatus(FF1DeviceStatus? status) {
    if (status == null || _syncedFromDevice) return;
    _volume = status.volume?.toDouble() ?? _volume;
    _isMuted = status.isMuted ?? _isMuted;
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

    final control = ref.read(ff1WifiControlProvider);
    final activeColor = widget.isEnable
        ? AppColor.white
        : AppColor.white.withValues(alpha: 0.4);

    return Row(
      children: [
        GestureDetector(
          onTap: widget.isEnable
              ? () async {
                  final prev = _isMuted;
                  setState(() => _isMuted = !_isMuted);
                  try {
                    await control.toggleMute(topicId: widget.topicId);
                  } on Exception catch (e) {
                    // Command failed — revert to last confirmed state.
                    setState(() => _isMuted = prev);
                    _log.warning('Error toggling mute: $e');
                  }
                }
              : null,
          child: Icon(
            _isMuted ? Icons.volume_off : Icons.volume_up,
            color: activeColor,
            size: widget.iconSize ?? LayoutConstants.iconSizeLarge,
          ),
        ),
        SizedBox(width: widget.gap ?? LayoutConstants.space2),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: activeColor,
              inactiveTrackColor: AppColor.white.withValues(alpha: 0.2),
              thumbColor: activeColor,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 6,
              ),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: _volume.clamp(0, 100),
              max: 100,
              // Drag updates local volume immediately for smooth feedback.
              onChanged: widget.isEnable
                  ? (v) => setState(() => _volume = v)
                  : null,
              onChangeEnd: widget.isEnable
                  ? (v) async {
                      final prevVolume = _volume;
                      try {
                        await control.setVolume(
                          topicId: widget.topicId,
                          percent: v.round(),
                        );
                      } on Exception catch (e) {
                        // Command failed — snap back to last confirmed volume.
                        setState(() => _volume = prevVolume);
                        _log.warning('Error setting volume: $e');
                      }
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
