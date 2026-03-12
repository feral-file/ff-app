import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1/loop_mode.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Loop (repeat) button for the now displaying bar.
///
/// Cycles through [LoopMode.none] → [LoopMode.playlist] → [LoopMode.one]
/// on each tap. Sends [FF1WifiControl.setLoop] via WiFi.
/// On error the state is reverted (optimistic update).
class LoopButton extends ConsumerStatefulWidget {
  const LoopButton({super.key});

  @override
  ConsumerState<LoopButton> createState() => _LoopButtonState();
}

class _LoopButtonState extends ConsumerState<LoopButton> {
  LoopMode _mode = LoopMode.none;

  @override
  void initState() {
    super.initState();
    final status = ref.read(ff1CurrentPlayerStatusProvider);
    _mode = status?.loopMode ?? LoopMode.none;
  }

  void _syncFromPlayerStatus(FF1PlayerStatus? status) {
    if (status?.loopMode case final value?) {
      if (mounted) setState(() => _mode = value);
    }
  }

  String? _topicId() {
    final status = ref.read(nowDisplayingProvider);
    if (status is! NowDisplayingSuccess ||
        status.object is! DP1NowDisplayingObject) {
      return null;
    }
    return (status.object as DP1NowDisplayingObject).connectedDevice.topicId;
  }

  Future<void> _handleTap() async {
    final topicId = _topicId();
    if (topicId == null || topicId.isEmpty) return;

    final previous = _mode;
    final next = previous.next;
    setState(() => _mode = next);

    try {
      await ref
          .read(ff1WifiControlProvider)
          .setLoop(topicId: topicId, mode: next);
    } on Exception catch (_) {
      if (mounted) setState(() => _mode = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ff1CurrentPlayerStatusProvider, (_, next) {
      _syncFromPlayerStatus(next);
    });

    final color = _mode == LoopMode.none
        ? PrimitivesTokens.colorsGrey
        : PrimitivesTokens.colorsWhite;

    final semanticsLabel = switch (_mode) {
      LoopMode.none => 'Loop off — tap to loop playlist',
      LoopMode.playlist => 'Looping playlist — tap to loop one',
      LoopMode.one => 'Looping one — tap to turn off loop',
    };

    final icon = SvgPicture.asset(
      'assets/images/loop.svg',
      width: 20,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: LayoutConstants.minTouchTarget * 0.75,
          height: LayoutConstants.minTouchTarget * 0.75,
          child: Center(
            child: switch (_mode) {
              LoopMode.none => icon,
              LoopMode.playlist => Stack(
                alignment: Alignment.center,
                children: [
                  icon,
                  Container(
                    width: LayoutConstants.space1,
                    height: LayoutConstants.space1,
                    decoration: const BoxDecoration(
                      color: PrimitivesTokens.colorsWhite,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              LoopMode.one => Stack(
                alignment: Alignment.center,
                children: [
                  icon,
                  Text(
                    '1',
                    style: AppTypography.bodySmall(context).bold.white.copyWith(
                      fontSize: 8,
                      height: 1,
                    ),
                  ),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}
