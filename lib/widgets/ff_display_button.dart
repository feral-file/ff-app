import 'dart:async';
import 'dart:math' as math;

import 'package:after_layout/after_layout.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/config/app_flags_store.dart';
import 'package:app/widgets/buttons/play_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:logging/logging.dart';
import 'package:sentry/sentry.dart';

/// Button that displays Play and triggers display-to-FF1 when an active
/// device exists.
///
/// Ported from old repo FFCastButton; renamed to FFDisplayButton.
/// Uses Riverpod for state (active device + tooltip seen flag).
class FFDisplayButton extends ConsumerStatefulWidget {
  const FFDisplayButton({
    super.key,
    this.onDeviceSelected,
    this.text,
    this.onTap,
    this.onTooltipVisibilityChanged,
  });

  final FutureOr<void> Function(FF1Device device)? onDeviceSelected;
  final String? text;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onTooltipVisibilityChanged;

  @override
  ConsumerState<FFDisplayButton> createState() => _FFDisplayButtonState();
}

class _FFDisplayButtonState extends ConsumerState<FFDisplayButton>
    with AfterLayoutMixin<FFDisplayButton> {
  static final _log = Logger('FFDisplayButton');

  bool _isProcessing = false;
  bool _showPlayTooltip = false;
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void afterFirstLayout(BuildContext context) {
    unawaited(_maybeShowPlayTooltip());
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _setShowPlayTooltip(bool value) {
    if (_showPlayTooltip == value) {
      return;
    }
    _showPlayTooltip = value;
    if (value) {
      _insertOverlay();
    } else {
      _removeOverlay();
    }
    setState(() {});
    widget.onTooltipVisibilityChanged?.call(value);
  }

  Future<void> _maybeShowPlayTooltip() async {
    final flagsStore = ref.read(appFlagsStoreProvider);
    final hasSeenTooltip = await flagsStore.getBool(hasSeenPlayToFf1TooltipKey);
    final activeAsync = ref.read(activeFF1BluetoothDeviceProvider);
    final hasCastingDevice = activeAsync.value != null;

    if (!mounted || hasSeenTooltip || !hasCastingDevice) {
      return;
    }

    _setShowPlayTooltip(true);
  }

  Future<void> _dismissTooltip() async {
    if (!_showPlayTooltip) {
      return;
    }
    _setShowPlayTooltip(false);
    final flagsStore = ref.read(appFlagsStoreProvider);
    await flagsStore.setBool(hasSeenPlayToFf1TooltipKey, true);
  }

  void _insertOverlay() {
    if (_overlayEntry != null || !mounted) {
      return;
    }
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _overlayEntry == null) {
          _insertOverlay();
        }
      });
      return;
    }
    _insertOverlayEntry(overlayState);
  }

  void _insertOverlayEntry(OverlayState overlay) {
    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenWidth = MediaQuery.of(context).size.width;
    final right = screenWidth - (offset.dx + size.width);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: AbsorbPointer(
              child: Container(
                color: PrimitivesTokens.colorsBlack.withValues(alpha: 0.6),
              ),
            ),
          ),
          Positioned(
            right: right,
            top: offset.dy,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayButton(
                  isProcessing: _isProcessing,
                  onTap: _handlePlayTap,
                ),
                SizedBox(height: LayoutConstants.space5),
                PlayToFF1Tooltip(
                  onDismiss: _dismissTooltip,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _handlePlayTap() async {
    await _dismissTooltip();
    setState(() {
      _isProcessing = true;
    });
    try {
      widget.onTap?.call();
      await _onTap();
    } on Object catch (e, stack) {
      _log.info('Error while displaying: $e');
      unawaited(
        Sentry.captureException(
          '[FFDisplayButton] Error while displaying: $e',
          stackTrace: stack,
        ),
      );
    }
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _onTap() async {
    final device = ref.read(activeFF1BluetoothDeviceProvider).value;
    if (device != null) {
      await widget.onDeviceSelected?.call(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(activeFF1BluetoothDeviceProvider);

    return activeAsync.when(
      data: (FF1Device? device) {
        if (device == null) {
          return const SizedBox.shrink();
        }
        return Container(
          key: _buttonKey,
          child: PlayButton(
            isProcessing: _isProcessing,
            onTap: () async {
              await _handlePlayTap();
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (Object e, StackTrace s) => const SizedBox.shrink(),
    );
  }
}

/// Tooltip explaining that tapping Play sends the playlist to FF1.
class PlayToFF1Tooltip extends StatelessWidget {
  const PlayToFF1Tooltip({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: LayoutConstants.space12 * 5),
            decoration: BoxDecoration(
              color: PrimitivesTokens.colorsDarkGrey,
              borderRadius: BorderRadius.circular(LayoutConstants.space2),
            ),
            child: Stack(
              children: [
                Container(
                  padding: EdgeInsets.all(LayoutConstants.space5),
                  child: Text(
                    'Tap the Play button to send the playlist to your FF1.',
                    style: AppTypography.body(context).white,
                  ),
                ),
                Positioned(
                  top: LayoutConstants.space3,
                  right: LayoutConstants.space3,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    child: SvgPicture.asset(
                      'assets/images/close.svg',
                      width: LayoutConstants.iconSizeSmall,
                      height: LayoutConstants.iconSizeSmall,
                      colorFilter: const ColorFilter.mode(
                        PrimitivesTokens.colorsGrey,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -LayoutConstants.space2,
            right: LayoutConstants.space8,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: LayoutConstants.iconSizeSmall,
                height: LayoutConstants.iconSizeSmall,
                color: PrimitivesTokens.colorsDarkGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
