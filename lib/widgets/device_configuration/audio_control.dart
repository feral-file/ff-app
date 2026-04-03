import 'package:app/app/providers/ff1_control_surface_providers.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/widgets/device_configuration/icon_slider_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Audio control: volume slider and mute toggle for an FF1 device.
///
/// The widget is intentionally thin: Riverpod owns device-status seeding,
/// optimistic reconciliation, and command side effects.
class AudioControl extends ConsumerWidget {
  /// Constructor.
  const AudioControl({
    required this.topicId,
    super.key,
    this.isEnable = true,
    this.gap,
    this.iconSize,
  });

  /// Device topic ID used to scope the control provider.
  final String topicId;

  /// Whether the controls are interactive. Disabled controls are rendered at
  /// reduced opacity and ignore taps/drags.
  final bool isEnable;

  /// Padding for the audio control.
  final double? gap;

  /// Icon size.
  final double? iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ff1AudioControlProvider(topicId));
    final notifier = ref.read(ff1AudioControlProvider(topicId).notifier);
    final enabled = isEnable && state.isTopicActive;

    return IconSliderControl(
      iconAsset: state.isMuted
          ? 'assets/images/icon_volume_muted.svg'
          : 'assets/images/icon_volume.svg',
      semanticLabel: 'Volume',
      enabled: enabled,
      iconEnabled: enabled,
      iconSize: iconSize ?? 18,
      gap: gap ?? LayoutConstants.space2,
      value: state.volume,
      onChanged: notifier.setVolumeDraft,
      onChangeEnd: (v) async {
        try {
          await notifier.commitVolume(v);
        } on Exception {
          // The provider owns rollback and reconciliation.
        }
      },
      onIconTap: () async {
        try {
          await notifier.toggleMute();
        } on Exception {
          // The provider owns rollback and reconciliation.
        }
      },
    );
  }
}
