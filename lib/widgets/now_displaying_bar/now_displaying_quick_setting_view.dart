import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/domain/models/now_displaying_object.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/now_displaying_bar/option_item_drawer_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Quick setting view for the now displaying bar (expanded state).
///
/// UI copied from old Feral File app (view/now_displaying/now_display_setting.dart).
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
  ArtFraming selectedFitment = ArtFraming.fitToScreen;

  List<OptionItem> _settingOptions() {
    final status = ref.read(nowDisplayingProvider);
    if (status is! NowDisplayingSuccess ||
        status.object is! DP1NowDisplayingObject) {
      return [];
    }
    final object = status.object as DP1NowDisplayingObject;
    final topicId = object.connectedDevice.topicId;
    final control = ref.read(ff1WifiControlProvider);

    OptionItem fitmentOption(ArtFraming fitment) {
      return OptionItem(
        title: fitment == ArtFraming.fitToScreen ? 'Fit' : 'Fill',
        icon: SvgPicture.asset(
          fitment == selectedFitment
              ? 'assets/images/radio_selected.svg'
              : 'assets/images/radio_unselected.svg',
        ),
        onTap: () async {
          await _updateFitment(fitment);
        },
      );
    }

    return [
      OptionItem(
        title: 'Rotate',
        icon: SvgPicture.asset('assets/images/icon_rotate_white.svg'),
        onTap: () async {
          try {
            await control.rotate(topicId: topicId);
          } catch (_) {}
        },
      ),
      fitmentOption(ArtFraming.fitToScreen),
      fitmentOption(ArtFraming.cropToFill),
    ];
  }

  Future<void> _updateFitment(ArtFraming fitment) async {
    if (fitment == selectedFitment) return;
    final status = ref.read(nowDisplayingProvider);
    if (status is! NowDisplayingSuccess ||
        status.object is! DP1NowDisplayingObject) {
      return;
    }
    final object = status.object as DP1NowDisplayingObject;
    final topicId = object.connectedDevice.topicId;
    final control = ref.read(ff1WifiControlProvider);
    try {
      await control.updateArtFraming(
        topicId: topicId,
        framing: fitment,
      );
      if (mounted) setState(() => selectedFitment = fitment);
    } catch (_) {}
  }

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
    final options = _settingOptions();
    final itemCount = options.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: itemCount,
          itemBuilder: (BuildContext context, int index) {
            final option = options[index];
            if (option.builder != null) {
              return option.builder!.call(context, option);
            }
            return DrawerItem(
              item: option,
              color: AppColor.white,
            );
          },
          separatorBuilder: (context, index) => (index == itemCount - 1)
              ? const SizedBox()
              : const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColor.white,
                ),
        ),
      ],
    );
  }
}
