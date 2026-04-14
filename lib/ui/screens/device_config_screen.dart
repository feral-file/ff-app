import 'dart:async';

import 'package:app/app/ff1/ff1_firmware_update_prompt_orchestrator.dart';
import 'package:app/app/ff1/ff1_firmware_update_prompt_service.dart';
import 'package:app/app/ff1/ff1_relayer_firmware_update_service.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/route_observer.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1/art_framing.dart';
import 'package:app/domain/models/ff1/screen_orientation.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/appbars/custom_app_bar.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:app/widgets/device_configuration/audio_control.dart';
import 'package:app/widgets/device_configuration/canvas_setting.dart';
import 'package:app/widgets/device_configuration/device_info_box.dart';
import 'package:app/widgets/device_configuration/device_metrics_section.dart';
import 'package:app/widgets/device_configuration/ffp_status_section.dart';
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
  bool _isRouteVisible = false;
  bool _isUpdatePromptPending = false;
  bool _isUpdatePromptDialogVisible = false;
  int _updatePromptGeneration = 0;

  /// App-layer session for auto firmware prompt (dedupe, in-flight guard).
  Ff1FirmwarePromptSessionState _promptSession =
      const Ff1FirmwarePromptSessionState();

  @override
  void initState() {
    super.initState();
    // Schedule an initial check after the first frame; device status may
    // already be available if the screen is opened while WiFi is connected.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdatePrompt());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      routeObserver.subscribe(this, route);
      _isRouteVisible = route.isCurrent;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    super.didPush();
    _isRouteVisible = true;
    _checkUpdatePrompt();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _isRouteVisible = true;
    _checkUpdatePrompt();
  }

  @override
  void didPushNext() {
    super.didPushNext();
    _isRouteVisible = false;
  }

  @override
  void didPop() {
    super.didPop();
    _isRouteVisible = false;
  }

  @override
  Widget build(BuildContext context) {
    // Prompt only on fresh relayer/connectivity updates. Active-device changes
    // alone can race with the auto-connect handoff and briefly expose stale
    // status from the previous device, so we avoid using them as a prompt
    // trigger.
    ref
      ..listen(
        ff1CurrentDeviceStatusProvider,
        (_, _) => _checkUpdatePrompt(),
      )
      ..listen(
        activeFF1BluetoothDeviceProvider,
        (previous, next) {
          final previousDeviceId = previous?.maybeWhen(
            data: (device) => device?.deviceId,
            orElse: () => null,
          );
          final nextDeviceId = next.maybeWhen(
            data: (device) => device?.deviceId,
            orElse: () => null,
          );
          if (previousDeviceId != nextDeviceId) {
            _updatePromptGeneration++;
            _isUpdatePromptPending = false;
            if (_isUpdatePromptDialogVisible && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_isUpdatePromptDialogVisible) {
                  return;
                }
                final navigator = Navigator.of(context, rootNavigator: true);
                if (navigator.canPop()) {
                  navigator.pop();
                }
              });
            }
          }
        },
      );

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
    final ffpStatusAsync = isDeviceConnected
        ? ref.watch(ff1FfpDdcPanelStatusStreamProvider(topicId))
        : null;
    final hasFfpStatus =
        ffpStatusAsync?.maybeWhen(
          data: (status) => status.hasData,
          orElse: () => false,
        ) ??
        false;

    // Legacy FF1 actions (rotate, canvas, system audio, pairing QR) follow the
    // normal playback/device-status gate — do not enable them while sleeping
    // or before player status exists.
    final isFf1DeviceConfigActionsControllable =
        isDeviceConnected &&
        deviceStatus != null &&
        playerStatus != null &&
        !(playerStatus.sleepMode ?? false) &&
        topicId.isNotEmpty;

    // FFP/DDC: require device-connected first (no panel stream or section when
    // disconnected). When connected, relayer-driven snapshot enables controls,
    // including setup and sleeping when status exists.
    final isFfpDdcControllable =
        isDeviceConnected && topicId.isNotEmpty && hasFfpStatus;

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
                isControllable: isFf1DeviceConfigActionsControllable,
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
                isControllable: isFf1DeviceConfigActionsControllable,
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
                      isEnable: isFf1DeviceConfigActionsControllable,
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: LayoutConstants.space5),
            ),
          ],
          if (widget.payload.isInSetupProcess) ...[
            if (isDeviceConnected) ...[
              SliverToBoxAdapter(
                child: FfpStatusSection(
                  topicId: topicId,
                  isConnected: isDeviceConnected,
                  isControllable: isFfpDdcControllable,
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SizedBox(
                height: LayoutConstants.space20,
              ),
            ),
          ] else ...[
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
                  isControllable: isFf1DeviceConfigActionsControllable,
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
                child: FfpStatusSection(
                  topicId: topicId,
                  isConnected: isDeviceConnected,
                  isControllable: isFfpDdcControllable,
                ),
              ),
            ],
            if (hasFfpStatus) ...[
              const SliverToBoxAdapter(
                child: Divider(
                  key: ValueKey('ffp_status_to_performance_divider'),
                  color: AppColor.primaryBlack,
                  thickness: 1,
                  height: 40,
                ),
              ),
            ],
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
  /// Called after the first frame and on each device status notification.
  /// Session dedupe tracks which latest version we already prompted for so a
  /// newer reported latest can show again without leaving this screen.
  void _checkUpdatePrompt() {
    if (!mounted || !_isRouteVisible) return;
    if (_isUpdatePromptPending) return;

    final deviceStatus = ref.read(ff1CurrentDeviceStatusProvider);
    final device = ref
        .read(activeFF1BluetoothDeviceProvider)
        .maybeWhen(data: (d) => d, orElse: () => null);

    final dismissedVersion = device == null
        ? ''
        : ref
              .read(ff1FirmwareUpdatePromptServiceProvider)
              .getDismissedLatestVersionForDevice(device.deviceId);

    final output = computeFirmwareUpdatePromptTick(
      session: _promptSession,
      activeDeviceId: device?.deviceId,
      isInSetupProcess: widget.payload.isInSetupProcess,
      isRelayerConnected: ref.read(ff1DeviceConnectedProvider),
      installedVersion: deviceStatus?.installedVersion,
      latestVersion: deviceStatus?.latestVersion,
      dismissedLatestVersionForDevice: dismissedVersion,
    );

    _promptSession = output.session;

    final show = output.show;
    if (show == null || device == null) {
      return;
    }

    // Keep one prompt request outstanding until the modal either shows or is
    // explicitly canceled by a device switch. Without this guard, back-to-back
    // status notifications can schedule duplicate dialogs before the first
    // post-frame callback runs.
    _isUpdatePromptPending = true;
    final promptGeneration = _updatePromptGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isRouteVisible) {
        _promptSession = Ff1FirmwarePromptSessionState(
          lastDeviceId: device.deviceId,
        );
        _isUpdatePromptPending = false;
        return;
      }

      if (promptGeneration != _updatePromptGeneration) {
        _promptSession = Ff1FirmwarePromptSessionState(
          lastDeviceId: device.deviceId,
        );
        _isUpdatePromptPending = false;
        return;
      }

      if (promptGeneration != _updatePromptGeneration) {
        _promptSession = Ff1FirmwarePromptSessionState(
          lastDeviceId: device.deviceId,
        );
        _isUpdatePromptPending = false;
        return;
      }

      unawaited(
        _showUpdatePromptDialog(
          device: device,
          installedVersion: show.installedVersion,
          latestVersion: show.latestVersion,
        ),
      );
    });
  }

  Future<void> _showUpdatePromptDialog({
    required FF1Device device,
    required String installedVersion,
    required String latestVersion,
  }) async {
    try {
      _isUpdatePromptDialogVisible = true;
      await _runUpdatePromptDialog(
        device: device,
        installedVersion: installedVersion,
        latestVersion: latestVersion,
      );
    } finally {
      if (mounted) {
        _promptSession = clearFirmwareUpdatePromptInFlight(_promptSession);
        _isUpdatePromptPending = false;
        _isUpdatePromptDialogVisible = false;
        _checkUpdatePrompt();
      }
    }
  }

  Future<void> _runUpdatePromptDialog({
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
            'A new version of FF1 firmware is available. '
            'Update now to get the latest improvements.',
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
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    // Save the dismissed version so the prompt won't reappear
                    // until latestVersion changes on the device.
                    await ref
                        .read(ff1FirmwareUpdatePromptServiceProvider)
                        .dismissLatestVersionForDevice(
                          deviceId: device.deviceId,
                          version: latestVersion,
                        );
                    if (!context.mounted) return;
                    navigator.pop(false);
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
                    final outcome = await ref
                        .read(ff1RelayerFirmwareUpdateServiceProvider)
                        .start(topicId: device.topicId);
                    if (!mounted) return;
                    switch (outcome) {
                      case Ff1RelayerFirmwareUpdateOutcome.success:
                        _log.info('[Update Prompt] Relayer accepted update');
                        // Success = command accepted; installed lags until OTA
                        // finishes. Dismiss like Later so finally does not
                        // re-offer the same latest build.
                        await ref
                            .read(ff1FirmwareUpdatePromptServiceProvider)
                            .dismissLatestVersionForDevice(
                              deviceId: device.deviceId,
                              version: latestVersion,
                            );
                        if (!mounted) return;
                        Navigator.pop(context, true);
                        return;
                      case Ff1RelayerFirmwareUpdateOutcome.missingTopic:
                        _log.warning('[Update Prompt] Missing topicId');
                        Navigator.pop(context, Exception('missing topic'));
                        return;
                      case Ff1RelayerFirmwareUpdateOutcome.relayerRejected:
                        _log.warning(
                          '[Update Prompt] Relayer returned unsuccessful '
                          'response',
                        );
                        Navigator.pop(context, Exception('relayer rejected'));
                        return;
                      case Ff1RelayerFirmwareUpdateOutcome.commandFailed:
                        _log.warning('[Update Prompt] Update command failed');
                        Navigator.pop(context, Exception('command failed'));
                        return;
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
      // Do not pass onClose: showInfoDialog already pops the sheet; an extra
      // context.pop() would remove DeviceConfigScreen underneath.
      await UIHelper.showInfoDialog(
        context,
        'Update Started',
        'The FF1 is now downloading and installing the latest '
            'firmware. It will restart automatically when complete.',
        closeButton: 'OK',
      );
    } else if (result is Exception || result is Error) {
      await UIHelper.showInfoDialog(
        context,
        'Update Failed',
        'Something went wrong while starting the update. Please try again.',
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
