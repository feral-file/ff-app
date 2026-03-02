import 'dart:async';

import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/domain/extensions/string_ext.dart';
import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:logging/logging.dart';

final _log = Logger('CanvasSetting');

/// Canvas item.
class CanvasItem {
  /// Constructor.
  CanvasItem({
    required this.title,
    required this.icon,
    this.titleStyle,
    this.titleStyleOnUnselected,
    this.iconOnUnselected,
    this.onSelected,
    this.onUnselected,
  });

  /// Title.
  final String title;

  /// Title style.
  final TextStyle? titleStyle;

  /// Title style on unselected.
  final TextStyle? titleStyleOnUnselected;

  /// Icon.
  final Widget icon;

  /// Icon on unselected.
  final Widget? iconOnUnselected;

  /// On selected.
  final FutureOr<void> Function()? onSelected;

  /// On unselected.
  final FutureOr<void> Function()? onUnselected;
}

/// Canvas setting.
class CanvasSetting extends ConsumerStatefulWidget {
  /// Constructor.
  const CanvasSetting({
    required this.selectedIndex,
    required this.topicId,
    super.key,
    this.isEnable = true,
  });

  /// Selected index.
  final int selectedIndex;

  /// Whether the canvas setting is enabled.
  final bool isEnable;

  /// Topic ID.
  final String topicId;

  @override
  ConsumerState<CanvasSetting> createState() => _CanvasSettingState();
}

/// Canvas setting state.
class _CanvasSettingState extends ConsumerState<CanvasSetting> {
  late int _selectedIndex;
  late FF1WifiControl control;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    control = ref.read(ff1WifiControlProvider);
  }

  @override
  void didUpdateWidget(covariant CanvasSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    _selectedIndex = widget.selectedIndex;
  }

  @override
  Widget build(BuildContext context) {
    final items = ArtFraming.values
        .map(
          (framing) => CanvasItem(
            title: framing.name.toTitleCase(),
            icon: Image.asset(
              framing == ArtFraming.fitToScreen
                  ? 'assets/images/fit.png'
                  : 'assets/images/fill.png',
              width: 100,
              height: 100,
            ),
            onSelected: () async {
              await control.updateArtFraming(
                topicId: widget.topicId,
                framing: framing,
              );
            },
          ),
        )
        .toList();

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
      ),
      itemCount: items.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedIndex == index && widget.isEnable;
        final activeTitleStyle =
            item.titleStyle ?? AppTypography.body(context).white;
        final inactiveTitleStyle =
            item.titleStyleOnUnselected ?? activeTitleStyle;
        final titleStyle = isSelected ? activeTitleStyle : inactiveTitleStyle;
        return GestureDetector(
          onTap: () async {
            if (!widget.isEnable) {
              return;
            }

            final currentIndex = _selectedIndex;

            setState(() {
              _selectedIndex = index;
            });

            try {
              await item.onSelected?.call();
            } on Exception catch (e) {
              _log.info('CanvasSetting: Error updating art framing: $e');
              if (mounted) {
                setState(() {
                  _selectedIndex = currentIndex;
                });
              }
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColor.white
                          : AppColor.disabledColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: item.icon,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SvgPicture.asset(
                    isSelected
                        ? 'assets/images/check_box_true.svg'
                        : 'assets/images/check_box_false.svg',
                    height: 12,
                    width: 12,
                    colorFilter: const ColorFilter.mode(
                      AppColor.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      item.title,
                      style: titleStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
