import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/domain/models/ff1/screen_orientation.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/appbars/custom_app_bar.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:app/widgets/device_configuration/canvas_setting.dart';
import 'package:app/widgets/device_configuration/device_info_box.dart';
import 'package:app/widgets/device_configuration/device_metrics_section.dart';
import 'package:app/widgets/device_configuration/options_button.dart';
import 'package:app/widgets/device_configuration/switch_device_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// Payload for the device config screen
class DeviceConfigPayload {
  /// Constructor
  DeviceConfigPayload({
    this.isInSetupProcess = true,
  });

  /// Whether the screen is in the setup process
  final bool isInSetupProcess;
}

/// Device config screen
class DeviceConfigScreen extends ConsumerStatefulWidget {
  /// Constructor
  const DeviceConfigScreen({
    required this.payload,
    super.key,
  });

  /// The payload for the device config screen
  final DeviceConfigPayload payload;

  @override
  ConsumerState<DeviceConfigScreen> createState() => _DeviceConfigScreenState();
}

class _DeviceConfigScreenState extends ConsumerState<DeviceConfigScreen>
    with RouteAware {
  bool _isShowingQRCode = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ref
        .watch(activeFF1BluetoothDeviceProvider)
        .maybeWhen(
          data: (device) {
            if (device == null) {
              return const SizedBox.shrink();
            }

            return Scaffold(
              appBar: getCustomBackAppBar(
                context,
                canGoBack: !widget.payload.isInSetupProcess,
                title: Text(
                  device.name,
                  style: AppTypography.body(context).white,
                ),
                actions: widget.payload.isInSetupProcess
                    ? []
                    : [
                        const SwitchDeviceButton(),
                        const OptionsButton(),
                      ],
              ),
              backgroundColor: AppColor.auGreyBackground,
              body: SafeArea(child: _body(context, device)),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
  }

  Widget _body(BuildContext context, FF1Device device) {
    final hasWifi = device.topicId.isNotEmpty;
    final deviceData = hasWifi
        ? ref.watch(ff1DeviceDataProvider)
        : const FF1DeviceData(
            deviceStatus: null,
            playerStatus: null,
            isConnected: false,
          );

    final isConnected = deviceData.isConnected;

    return Stack(
      children: [
        _deviceConfig(device: device, deviceData: deviceData),
        if (widget.payload.isInSetupProcess)
          Positioned(
            bottom: LayoutConstants.space4,
            left: LayoutConstants.pageHorizontalDefault,
            right: LayoutConstants.pageHorizontalDefault,
            child: PrimaryAsyncButton(
              padding: const EdgeInsets.only(top: 13, bottom: 10),
              onTap: () async {
                context.go(Routes.home);
              },
              text: 'Finish',
              color: PrimitivesTokens.colorsLightBlue,
            ),
          ),
        if (widget.payload.isInSetupProcess && !isConnected)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: isConnected ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 500),
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      SizedBox(height: LayoutConstants.space4),
                      Text(
                        'FF1 is getting ready',
                        style: AppTypography.body(context).white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _deviceConfig({
    required FF1Device device,
    required FF1DeviceData deviceData,
  }) {
    final topicId = device.topicId;

    final deviceStatus = deviceData.deviceStatus;
    final playerStatus = deviceData.playerStatus;
    final isDeviceConnected = deviceData.isConnected;

    final control = ref.read(ff1WifiControlProvider);

    final isControllable =
        isDeviceConnected &&
        deviceStatus != null &&
        playerStatus != null &&
        !playerStatus.isSleeping &&
        topicId.isNotEmpty;

    return Padding(
      padding: EdgeInsets.zero,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.paddingOf(context).top + 32,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: LayoutConstants.pageHorizontalDefault,
              ),
              child: _displayOrientation(
                control,
                topicId: topicId,
                screenOrientation: deviceStatus?.screenRotation,
                isControllable: isControllable,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Divider(
              color: AppColor.primaryBlack,
              thickness: 1,
              height: LayoutConstants.space10,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: LayoutConstants.pageHorizontalDefault,
              ),
              child: _canvasSetting(
                context,
                control,
                scaling: playerStatus?.deviceSettings?.scaling,
                topicId: topicId,
                isControllable: isControllable,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: LayoutConstants.space5,
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(
              color: AppColor.primaryBlack,
              thickness: 1,
              height: 1,
            ),
          ),
          if (!widget.payload.isInSetupProcess) ...[
            const SliverToBoxAdapter(
              child: SizedBox(
                height: 20,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: LayoutConstants.pageHorizontalDefault,
                ),
                child: _deviceInfo(
                  context,
                  control,
                  device: device,
                  deviceData: deviceData,
                  isControllable: isControllable,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Divider(
                color: AppColor.primaryBlack,
                thickness: 1,
                height: 40,
              ),
            ),

            if (isDeviceConnected) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: LayoutConstants.pageHorizontalDefault,
                  ),
                  child: DeviceMetricsSection(
                    key: ValueKey(topicId),
                    topicId: topicId,
                    isConnected: isDeviceConnected,
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(
                height: LayoutConstants.space12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _displayOrientationPreview(ScreenOrientation? screenOrientation) {
    return Container(
      decoration: BoxDecoration(
        color: AppColor.primaryBlack,
        borderRadius: BorderRadius.circular(10),
      ),
      height: 200,
      child: Center(
        child: _displayOrientationPreviewImage(
          screenOrientation,
        ),
      ),
    );
  }

  Widget _displayOrientationPreviewImage(ScreenOrientation? screenOrientation) {
    if (screenOrientation == null) {
      return const SizedBox.shrink();
    }

    switch (screenOrientation) {
      case ScreenOrientation.landscape:
        return SvgPicture.asset(
          'assets/images/landscape.svg',
          width: 150,
        );
      case ScreenOrientation.landscapeReverse:
        return RotatedBox(
          quarterTurns: 2,
          child: SvgPicture.asset(
            'assets/images/landscape.svg',
            width: 150,
          ),
        );
      case ScreenOrientation.portrait:
        return SvgPicture.asset(
          'assets/images/portrait.svg',
          height: 150,
        );
      case ScreenOrientation.portraitReverse:
        return RotatedBox(
          quarterTurns: 2,
          child: SvgPicture.asset(
            'assets/images/portrait.svg',
            height: 150,
          ),
        );
    }
  }

  Widget _displayOrientation(
    FF1WifiControl control, {
    required ScreenOrientation? screenOrientation,
    required String topicId,
    required bool isControllable,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Display Orientation',
          style: AppTypography.body(context).white,
        ),
        SizedBox(height: LayoutConstants.space4),
        _displayOrientationPreview(screenOrientation),
        SizedBox(height: LayoutConstants.space4),
        PrimaryAsyncButton(
          text: 'Rotate',
          color: AppColor.white,
          enabled: isControllable,
          onTap: () async {
            await control.rotate(topicId: topicId);
          },
        ),
      ],
    );
  }

  Widget _canvasSetting(
    BuildContext context,
    FF1WifiControl control, {
    required ArtFraming? scaling,
    required String topicId,
    required bool isControllable,
  }) {
    final artFramingIndex = scaling == ArtFraming.cropToFill ? 1 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Canvas',
          style: AppTypography.body(context).white,
        ),
        SizedBox(height: LayoutConstants.space6 + LayoutConstants.space2),
        CanvasSetting(
          selectedIndex: artFramingIndex,
          isEnable: isControllable,
          topicId: topicId,
        ),
      ],
    );
  }

  Widget _deviceInfo(
    BuildContext context,
    FF1WifiControl control, {
    required FF1Device device,
    required FF1DeviceData deviceData,
    required bool isControllable,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Device Information',
                style: AppTypography.body(context).white,
              ),
            ),
          ],
        ),
        SizedBox(height: LayoutConstants.space4),
        DeviceInfoBox(
          device: device,
          deviceData: deviceData,
        ),
        if (isControllable) ...[
          SizedBox(height: LayoutConstants.space4),
          PrimaryAsyncButton(
            text: _isShowingQRCode ? 'Hide QR Code' : 'Show Pairing QR Code',
            color: AppColor.white,
            onTap: () async {
              await control.showPairingQRCode(
                topicId: device.topicId,
                show: !_isShowingQRCode,
              );
              setState(() {
                _isShowingQRCode = !_isShowingQRCode;
              });
            },
          ),
        ],
        SizedBox(height: LayoutConstants.space8),
      ],
    );
  }
}
