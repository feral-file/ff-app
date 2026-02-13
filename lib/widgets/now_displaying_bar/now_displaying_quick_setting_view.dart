import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quick setting view for the now displaying bar (expanded state).
///
/// Shows Rotate, Fit, and Fill options. Data from [nowDisplayingProvider];
/// commands via [ff1WifiControlProvider].
class NowDisplayingQuickSettingView extends ConsumerStatefulWidget {
  const NowDisplayingQuickSettingView({super.key});

  @override
  ConsumerState<NowDisplayingQuickSettingView> createState() =>
      _NowDisplayingQuickSettingViewState();
}

class _NowDisplayingQuickSettingViewState
    extends ConsumerState<NowDisplayingQuickSettingView> {
  ArtFraming _selectedFitment = ArtFraming.fitToScreen;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(nowDisplayingProvider);
    if (status is! NowDisplayingSuccess) {
      return const SizedBox.shrink();
    }
    final object = status.object;
    if (object is! DP1NowDisplayingObject) {
      return const SizedBox.shrink();
    }

    final topicId = object.connectedDevice.topicId;
    final control = ref.read(ff1WifiControlProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OptionRow(
          label: 'Rotate',
          onTap: () async {
            try {
              await control.rotate(topicId: topicId, angle: 90);
            } catch (_) {}
          },
        ),
        Divider(
          height: LayoutConstants.space1,
          thickness: LayoutConstants.space1,
          color: PrimitivesTokens.colorsWhite,
        ),
        _OptionRow(
          label: 'Fit',
          isSelected: _selectedFitment == ArtFraming.fitToScreen,
          onTap: () async {
            try {
              await control.updateArtFraming(
                topicId: topicId,
                framing: ArtFraming.fitToScreen,
              );
              if (mounted) {
                setState(() => _selectedFitment = ArtFraming.fitToScreen);
              }
            } catch (_) {}
          },
        ),
        Divider(
          height: LayoutConstants.space1,
          thickness: LayoutConstants.space1,
          color: PrimitivesTokens.colorsWhite,
        ),
        _OptionRow(
          label: 'Fill',
          isSelected: _selectedFitment == ArtFraming.cropToFill,
          onTap: () async {
            try {
              await control.updateArtFraming(
                topicId: topicId,
                framing: ArtFraming.cropToFill,
              );
              if (mounted) {
                setState(() => _selectedFitment = ArtFraming.cropToFill);
              }
            } catch (_) {}
          },
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: LayoutConstants.minTouchTarget,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: LayoutConstants.space3,
              horizontal: LayoutConstants.space2,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: LayoutConstants.iconSizeMedium,
                  color: PrimitivesTokens.colorsWhite,
                ),
                SizedBox(width: LayoutConstants.space3),
                Text(
                  label,
                  style: AppTypography.body(context).white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
