import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shuffle toggle button for the now displaying bar.
///
/// Manages its own enabled/disabled state. Sends [FF1WifiControl.setShuffle]
/// via WiFi. On error the state is reverted (optimistic update).
class ShuffleButton extends ConsumerStatefulWidget {
  const ShuffleButton({super.key});

  @override
  ConsumerState<ShuffleButton> createState() => _ShuffleButtonState();
}

class _ShuffleButtonState extends ConsumerState<ShuffleButton> {
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    final status = ref.read(ff1CurrentPlayerStatusProvider);
    _isEnabled = status?.shuffle ?? false;
  }

  void _syncFromPlayerStatus(FF1PlayerStatus? status) {
    if (status?.shuffle case final value?) {
      if (mounted) setState(() => _isEnabled = value);
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

    final previous = _isEnabled;
    final next = !previous;
    setState(() => _isEnabled = next);

    try {
      await ref
          .read(ff1WifiControlProvider)
          .setShuffle(topicId: topicId, enabled: next);
    } on Exception catch (_) {
      if (mounted) setState(() => _isEnabled = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(ff1CurrentPlayerStatusProvider, (_, next) {
      _syncFromPlayerStatus(next);
    });

    return Semantics(
      label: _isEnabled ? 'Disable shuffle' : 'Enable shuffle',
      button: true,
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: LayoutConstants.minTouchTarget * 0.75,
          height: LayoutConstants.minTouchTarget * 0.75,
          child: Center(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                SvgPicture.asset(
                  'assets/images/shuffle.svg',
                  width: 20,
                  colorFilter: ColorFilter.mode(
                    _isEnabled
                        ? PrimitivesTokens.colorsWhite
                        : PrimitivesTokens.colorsGrey,
                    BlendMode.srcIn,
                  ),
                ),
                if (_isEnabled)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: PrimitivesTokens.colorsWhite,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
