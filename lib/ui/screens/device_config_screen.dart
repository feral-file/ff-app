import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/domain/models/ff1/screen_orientation.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/appbars/custom_app_bar.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:app/widgets/device_configuration/audio_control.dart';
import 'package:app/widgets/device_configuration/canvas_setting.dart';
import 'package:app/widgets/device_configuration/device_info_box.dart';
import 'package:app/widgets/device_configuration/device_metrics_section.dart';
import 'package:app/widgets/device_configuration/options_button.dart';
import 'package:app/widgets/device_configuration/switch_device_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

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

final _log = Logger('DeviceConfigScreen');

class _DeviceConfigScreenState extends ConsumerState<DeviceConfigScreen>
    with RouteAware {
  bool _isShowingQRCode = false;

  /// Guards so the update prompt appears at most once per screen visit.
  bool _hasShownUpdatePrompt = false;

  @override
  void initState() {
    super.initState();
    // Schedule an initial check after the first frame; device status may
    // already be available if the screen is opened while WiFi is connected.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdatePrompt());
  }

  @override
  Widget build(BuildContext context) {
    // React to device status arriving late (e.g. WiFi connects after screen open).
    ref.listen(ff1CurrentDeviceStatusProvider, (_, __) => _checkUpdatePrompt());

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
          if (deviceStatus?.volume != null &&
              deviceStatus?.isMuted != null) ...[
            const SliverToBoxAdapter(
              child: Divider(
                color: AppColor.primaryBlack,
                thickness: 1,
                height: 1,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: LayoutConstants.pageHorizontalDefault,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: LayoutConstants.space5),
                    Text(
                      'Audio',
                      style: AppTypography.body(context).white,
                    ),
                    SizedBox(height: LayoutConstants.space3),
                    AudioControl(
                      topicId: topicId,
                      isEnable: isControllable,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: LayoutConstants.space5),
            ),
          ],
          const SliverToBoxAdapter(
            child: Divider(
              color: AppColor.primaryBlack,
              thickness: 1,
              height: 1,
            ),
          ),
          if (widget.payload.isInSetupProcess) ...[
            SliverToBoxAdapter(
              child: SizedBox(
                height: LayoutConstants.space20,
              ),
            ),
          ],
          if (!widget.payload.isInSetupProcess) ...[
            SliverToBoxAdapter(
              child: SizedBox(
                height: LayoutConstants.space5,
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

  // ===========================================================================
  // Update prompt
  // ===========================================================================

  /// Checks whether an update prompt should be shown and schedules it.
  ///
  /// Called once after the first frame (initState) and every time device status
  /// changes (ref.listen). The [_hasShownUpdatePrompt] flag ensures the dialog
  /// appears at most once per screen visit regardless of how many status
  /// notifications arrive.
  void _checkUpdatePrompt() {
    if (_hasShownUpdatePrompt || !mounted) return;

    final deviceStatus = ref.read(ff1CurrentDeviceStatusProvider);
    final device = ref
        .read(activeFF1BluetoothDeviceProvider)
        .maybeWhen(data: (d) => d, orElse: () => null);
    if (device == null || deviceStatus == null) return;

    final latestVersion = deviceStatus.latestVersion;
    final installedVersion = deviceStatus.installedVersion;
    if (latestVersion == null ||
        installedVersion == null ||
        latestVersion == installedVersion) {
      return;
    }

    final dismissedVersion = ref
        .read(appStateServiceProvider)
        .getDismissedUpdateVersion(device.deviceId);
    if (dismissedVersion == latestVersion) return;

    _hasShownUpdatePrompt = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _showUpdatePromptDialog(
          device: device,
          installedVersion: installedVersion,
          latestVersion: latestVersion,
        ),
      );
    });
  }

  Future<void> _showUpdatePromptDialog({
    required FF1Device device,
    required String installedVersion,
    required String latestVersion,
  }) async {
    final result = await UIHelper.showCenterDialog(
      context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update Available',
            style: AppTypography.body(context).bold.white,
          ),
          SizedBox(height: LayoutConstants.space4),
          Text(
            'A new version of FF1 firmware is available. Update now to get the latest improvements.',
            style: AppTypography.body(context).white,
          ),
          SizedBox(height: LayoutConstants.space10),
          Row(
            children: [
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Later',
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () {
                    // Save the dismissed version so the prompt won't reappear
                    // until latestVersion changes on the device.
                    unawaited(
                      ref
                          .read(appStateServiceProvider)
                          .setDismissedUpdateVersion(
                            deviceId: device.deviceId,
                            version: latestVersion,
                          ),
                    );
                    Navigator.pop(context, false);
                  },
                ),
              ),
              SizedBox(width: LayoutConstants.space4),
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Update Now',
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () async {
                    try {
                      var success = false;

                      if (device.topicId.isNotEmpty) {
                        try {
                          _log.info(
                            '[Update Prompt] Attempting via WiFi',
                          );
                          final response = await ref
                              .read(ff1WifiControlProvider)
                              .updateToLatestVersion(
                                topicId: device.topicId,
                              );
                          final dataOk = response.data?['ok'];
                          success = dataOk is bool
                              ? dataOk
                              : (response.status?.toLowerCase() == 'ok' ||
                                    response.status?.toLowerCase() ==
                                        'success' ||
                                    response.status == null);
                          if (!success) {
                            _log.warning(
                              '[Update Prompt] WiFi returned unsuccessful response, falling back to BLE',
                            );
                          }
                        } on Exception catch (e) {
                          _log.warning(
                            '[Update Prompt] WiFi error: $e, falling back to BLE',
                          );
                        }
                      }

                      if (!success) {
                        _log.info(
                          '[Update Prompt] Attempting via Bluetooth',
                        );
                        await ref
                            .read(ff1ControlProvider)
                            .updateToLatestVersion(
                              blDevice: device.toBluetoothDevice(),
                            );
                        success = true;
                      }

                      if (mounted) {
                        Navigator.pop(context, success);
                      }
                    } on Exception catch (e) {
                      _log.warning('[Update Prompt] Update failed: $e');
                      if (mounted) {
                        Navigator.pop(context, e);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (result is bool && result) {
      await UIHelper.showInfoDialog(
        context,
        'Update Started',
        'The FF1 is now downloading and installing the latest firmware. It will restart automatically when complete.',
        closeButton: 'OK',
        onClose: () => context.pop(),
      );
    } else if (result is Exception || result is Error) {
      await UIHelper.showInfoDialog(
        context,
        'Update Failed',
        'Something went wrong while starting the update. Please try again from the options menu.',
      );
    }
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
