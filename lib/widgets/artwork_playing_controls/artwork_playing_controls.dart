import 'dart:async';

import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/device_configuration/audio_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// Playback controls overlay shown when a work is actively playing on FF1.
///
/// Shows Rotate, Fit/Fill, Volume, and Interact controls. Commands are sent
/// via the WiFi control layer using the connected device's [FF1Device.topicId].
class ArtworkPlayingControls extends ConsumerStatefulWidget {
  const ArtworkPlayingControls({
    required this.playingDevice,
    super.key,
  });

  final FF1Device playingDevice;

  @override
  ConsumerState<ArtworkPlayingControls> createState() =>
      _ArtworkPlayingControlsState();
}

class _ArtworkPlayingControlsState
    extends ConsumerState<ArtworkPlayingControls> {
  /// Current framing selection, kept in local UI state.
  ArtFraming _selectedFraming = ArtFraming.fitToScreen;

  String get _topicId => widget.playingDevice.topicId;

  Future<void> _rotate() async {
    if (_topicId.isEmpty) return;
    final control = ref.read(ff1WifiControlProvider);
    try {
      await control.rotate(topicId: _topicId);
    } catch (_) {}
  }

  Future<void> _setFraming(ArtFraming framing) async {
    if (framing == _selectedFraming || _topicId.isEmpty) return;
    final control = ref.read(ff1WifiControlProvider);
    try {
      await control.updateArtFraming(topicId: _topicId, framing: framing);
      if (mounted) setState(() => _selectedFraming = framing);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 243 / 393,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        color: PrimitivesTokens.colorsDarkGrey,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlButton(
            label: 'Rotate',
            leading: Transform.flip(
              flipY: true,
              child: SvgPicture.asset(
                'assets/images/icon_rotate_white.svg',
                width: 13.71,
                height: 18,
              ),
            ),
            onTap: _rotate,
          ),
          SizedBox(height: LayoutConstants.space3),
          Row(
            children: [
              Expanded(
                child: _FramingButton(
                  label: 'Fit',
                  isSelected: _selectedFraming == ArtFraming.fitToScreen,
                  onTap: () => _setFraming(ArtFraming.fitToScreen),
                ),
              ),
              SizedBox(width: LayoutConstants.space3),
              Expanded(
                child: _FramingButton(
                  label: 'Fill',
                  isSelected: _selectedFraming == ArtFraming.cropToFill,
                  onTap: () => _setFraming(ArtFraming.cropToFill),
                ),
              ),
            ],
          ),
          SizedBox(height: LayoutConstants.space3),
          // Volume control row — wrapped in same black pill as other controls.
          Container(
            padding: EdgeInsets.symmetric(
              vertical: 10,
              horizontal: LayoutConstants.space3,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: PrimitivesTokens.colorsBlack,
            ),
            child: AudioControl(
              topicId: _topicId,
              gap: LayoutConstants.space2,
              iconSize: 18,
            ),
          ),
          SizedBox(height: LayoutConstants.space3),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push(Routes.keyboardControl),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.primaryBlack,
                padding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: LayoutConstants.space3,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              child: Text(
                'Interact',
                style: AppTypography.body(context).white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single-row async control button (e.g. Rotate).
class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.label,
    required this.onTap,
    this.leading,
  });

  final String label;
  final Widget? leading;
  final Future<void> Function() onTap;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isProcessing
          ? null
          : () async {
              setState(() => _isProcessing = true);
              await widget.onTap();
              if (mounted) setState(() => _isProcessing = false);
            },
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 10,
          horizontal: LayoutConstants.space3,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: PrimitivesTokens.colorsBlack,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isProcessing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColor.white,
                ),
              )
            else if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: 8),
            ],
            Text(
              widget.label,
              style: AppTypography.bodySmall(
                context,
              ).copyWith(color: PrimitivesTokens.colorsWhite),
            ),
          ],
        ),
      ),
    );
  }
}

/// A framing toggle button (Fit / Fill) with radio indicator.
class _FramingButton extends StatelessWidget {
  const _FramingButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: 10,
          horizontal: LayoutConstants.space3,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: PrimitivesTokens.colorsBlack,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 11,
              width: 11,
              decoration: const BoxDecoration(
                color: PrimitivesTokens.colorsDarkGrey,
                shape: BoxShape.circle,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        height: 6,
                        width: 6,
                        decoration: const BoxDecoration(
                          color: PrimitivesTokens.colorsWhite,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.bodySmall(
                context,
              ).copyWith(color: PrimitivesTokens.colorsWhite),
            ),
          ],
        ),
      ),
    );
  }
}
