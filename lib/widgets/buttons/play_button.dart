import 'dart:async';

import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Play button used for display-to-FF1 actions.
///
/// Uses design tokens for colors and spacing (no PlayButtonTokens in ff-app).
class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    this.onTap,
    this.enabled = true,
    this.isProcessing = false,
    this.text = 'Play',
  });

  final VoidCallback? onTap;
  final bool enabled;
  final bool isProcessing;
  final String text;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: LayoutConstants.space3,
          vertical: LayoutConstants.space2,
        ),
        decoration: BoxDecoration(
          color: PrimitivesTokens.colorsLightBlue,
          borderRadius: BorderRadius.circular(LayoutConstants.space10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: AppTypography.body(context).copyWith(
                color: PrimitivesTokens.colorsBlack,
              ),
            ),
            SizedBox(width: LayoutConstants.space3),
            Stack(
              children: [
                SvgPicture.asset(
                  'assets/images/play_icon.svg',
                  width: LayoutConstants.iconSizeSmall,
                  height: LayoutConstants.iconSizeSmall,
                  colorFilter: const ColorFilter.mode(
                    PrimitivesTokens.colorsBlack,
                    BlendMode.srcIn,
                  ),
                ),
                if (isProcessing)
                  const Positioned(
                    top: 0,
                    right: 0,
                    child: ProcessingIndicator(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small animated dot shown while a play/display action is in progress.
class ProcessingIndicator extends StatefulWidget {
  const ProcessingIndicator({super.key});

  @override
  State<ProcessingIndicator> createState() => _ProcessingIndicatorState();
}

class _ProcessingIndicatorState extends State<ProcessingIndicator> {
  int _colorIndex = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _colorIndex = (_colorIndex + 1) % 2;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColor.primaryBlack,
      AppColor.feralFileLightBlue,
    ];
    final color = colors[_colorIndex];
    return Container(
      width: LayoutConstants.space1,
      height: LayoutConstants.space1,
      margin: EdgeInsets.only(top: LayoutConstants.space1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
