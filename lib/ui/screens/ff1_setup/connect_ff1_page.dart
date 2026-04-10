import 'dart:async';

import 'package:app/app/ff1_setup/ff1_setup_effect.dart';
import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/scan_wifi_network_screen.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif_view/gif_view.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

enum _ConnectFF1Status {
  connecting,
  stillConnecting,
  bluetoothOff,
  error,
  success,
  portalIsSet,
}

final _log = Logger('ConnectFF1Page');

/// Payload for the connect FF1 page
class ConnectFF1PagePayload {
  /// Constructor
  ConnectFF1PagePayload({
    required this.device,
    required this.ff1DeviceInfo,
  });

  /// Bluetooth device to connect to (required).
  final BluetoothDevice device;

  /// Optional device info parsed from deeplink or other source.
  /// When non-null, used to skip get_info command and provide metadata early.
  final FF1DeviceInfo? ff1DeviceInfo;
}

/// Connect FF1 page
class ConnectFF1Page extends ConsumerStatefulWidget {
  /// Constructor
  const ConnectFF1Page({
    required this.payload,
    super.key,
  });

  /// Payload for the page
  final ConnectFF1PagePayload payload;

  @override
  ConsumerState<ConnectFF1Page> createState() => _ConnectFF1PageState();
}

class _ConnectFF1PageState extends ConsumerState<ConnectFF1Page> {
  DateTime? _startTime;
  FF1SetupOrchestratorNotifier? _setupOrchestrator;
  ProviderSubscription<FF1SetupState>? _setupSub;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    // Navigation + dialog side-effects must not be registered inside build.
    _setupSub = ref.listenManual<FF1SetupState>(
      ff1SetupOrchestratorProvider,
      (previous, next) {
        final effectId = next.effectId;
        final effect = next.effect;
        if (previous?.effectId != effectId && effect != null) {
          final orchestrator = ref.read(ff1SetupOrchestratorProvider.notifier);
          unawaited(() async {
            final didHandle = await _handleOrchestratorEffect(effect);
            if (didHandle) {
              orchestrator.ackEffect(effectId: effectId);
            }
          }());
        }
      },
    );

    _setupOrchestrator = ref.read(ff1SetupOrchestratorProvider.notifier);

    // Start the BLE flow only after this frame has built and watched the
    // orchestrator. A microtask can run before [build] runs, which means
    // [FF1SetupOrchestratorNotifier.build] may not have registered
    // [ref.listen(connectFF1Provider)] yet — connect would reach terminal
    // [ConnectFF1Connected] with no listener to emit navigation effects.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_startConnectFlow());
    });
  }

  @override
  void dispose() {
    // Cancel connection if still in progress
    _setupOrchestrator?.cancel();
    _setupSub?.close();
    super.dispose();
  }

  /// Map provider state to UI status
  _ConnectFF1Status _getStatusFromSetupState(FF1SetupState state) {
    if (state.connected?.portalIsSet == true) {
      return _ConnectFF1Status.portalIsSet;
    }

    return switch (state.step) {
      FF1SetupStep.connecting => _ConnectFF1Status.connecting,
      FF1SetupStep.stillConnecting => _ConnectFF1Status.stillConnecting,
      FF1SetupStep.bluetoothOff => _ConnectFF1Status.bluetoothOff,
      FF1SetupStep.error => _ConnectFF1Status.error,
      FF1SetupStep.readyForConfig => _ConnectFF1Status.success,
      _ => _ConnectFF1Status.connecting,
    };
  }

  Future<bool> _handleOrchestratorEffect(FF1SetupEffect effect) async {
    switch (effect) {
      case FF1SetupInternetReady(:final connected):
        _recordDuration(success: true);
        if (!connected.portalIsSet && context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            context.replace(Routes.deviceConfiguration);
          });
        }
        return true;
      case FF1SetupNeedsWiFi(:final device):
        if (!context.mounted) return false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.replace(
            Routes.scanWifiNetworks,
            extra: ScanWifiNetworkPagePayload(device: device),
          );
        });
        return true;
      case FF1SetupNavigate():
        // Navigation effects can be emitted by downstream Wi‑Fi steps.
        // When this page sits below those routes in the stack, handling them
        // here can target the wrong navigator and swallow the effect for the
        // active screen. Let the top-most screen consume these effects.
        return false;
      case FF1SetupPop():
        // Pop is owned by the active route (e.g. cancel CTA on the current
        // page).
        return false;
      case FF1SetupDeviceUpdating():
        if (!context.mounted) return false;
        context.go(Routes.ff1Updating);
        return true;
      case FF1SetupShowError(
        :final title,
        :final message,
        :final showSupportCta,
      ):
        _recordDuration(success: false);
        if (!context.mounted) return false;
        final supportEmailService = showSupportCta
            ? ref.read(supportEmailServiceProvider)
            : null;
        await UIHelper.showInfoDialog(
          context,
          title,
          message,
          closeButton: showSupportCta ? 'Contact support' : '',
          onClose: showSupportCta
              ? (nextContext) {
                  return UIHelper.showCustomerSupport(
                    nextContext,
                    supportEmailService: supportEmailService!,
                  );
                }
              : null,
        );
        return true;
      case FF1SetupEnterWifiPassword():
        // Not expected on this screen; ignore.
        return false;
    }
  }

  Future<void> _startConnectFlow() async {
    _startTime = DateTime.now();
    _log.info('[ConnectFF1Page] Start connecting to FF1');
    final notifier = _setupOrchestrator;
    if (notifier == null) {
      return;
    }
    await notifier.startConnect(
      device: widget.payload.device,
      deeplinkInfo: widget.payload.ff1DeviceInfo,
    );
  }

  void _recordDuration({required bool success}) {
    if (_startTime == null) {
      return;
    }
    final duration = DateTime.now().difference(_startTime!);
    final ms = duration.inMilliseconds;
    String bucket;
    if (duration.inSeconds < 5) {
      bucket = '<5s';
    } else if (duration.inSeconds <= 10) {
      bucket = '5-10s';
    } else {
      bucket = '>10s';
    }
    _log.info(
      '[ConnectFF1Page] Connection ${success ? "success" : "failure"} '
      'duration=${duration.inSeconds}s (${ms}ms), bucket=$bucket',
    );
  }

  Future<void> _onCancel() async {
    _log.info('[ConnectFF1Page] Cancel pressed, cancelling connection');
    _setupOrchestrator?.cancel();
    try {
      await widget.payload.device.disconnect();
    } on Object catch (e) {
      _log.info('[ConnectFF1Page] Error while disconnecting: $e');
    }

    if (!mounted) {
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(ff1SetupOrchestratorProvider);
    _log.info('UI state -> $setupState');
    final status = _getStatusFromSetupState(setupState);

    return Scaffold(
      appBar: const SetupAppBar(
        withDivider: false,
      ),
      backgroundColor: AppColor.auGreyBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: LayoutConstants.space4,
            horizontal: LayoutConstants.setupPageHorizontal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (status == _ConnectFF1Status.bluetoothOff) {
                      return _bluetoothNotAvailableView(context);
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (status == _ConnectFF1Status.error) ...[
                          Icon(
                            Icons.error,
                            size: LayoutConstants.iconSizeLarge * 2,
                            color: PrimitivesTokens.colorsLightBlue,
                          ),
                          SizedBox(height: LayoutConstants.space4),
                        ] else ...[
                          if (status == _ConnectFF1Status.portalIsSet)
                            Image.asset(
                              'assets/images/ff_logo.png',
                              width: 139,
                              height: 92.67,
                            )
                          else
                            GifView.asset(
                              'assets/images/loading.gif',
                              width: 139,
                              height: 92.67,
                              frameRate: 12,
                            ),
                          const SizedBox(height: 85),
                        ],
                        Align(
                          alignment: status == _ConnectFF1Status.error
                              ? Alignment.center
                              : Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment:
                                status == _ConnectFF1Status.error
                                ? CrossAxisAlignment.center
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getTitleText(status),
                                style: AppTypography.h2(context).white,
                              ),
                              SizedBox(height: LayoutConstants.space5),
                              Text(
                                _getBodyText(status),
                                style: AppTypography.body(context).white,
                              ),
                              if (status == _ConnectFF1Status.portalIsSet) ...[
                                SizedBox(height: LayoutConstants.space5),
                                PrimaryButton(
                                  onTap: () async {
                                    if (context.mounted) {
                                      context.replace(
                                        Routes.deviceConfiguration,
                                      );
                                    }
                                  },
                                  text: 'Go to Settings',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              if (status == _ConnectFF1Status.error) ...[
                SizedBox(height: LayoutConstants.space6),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        key: GoldPathPatrolKeys.connectFF1Retry,
                        text: 'Try Again',
                        onTap: _startConnectFlow,
                        color: AppColor.white,
                        textColor: AppColor.primaryBlack,
                      ),
                    ),
                    SizedBox(width: LayoutConstants.space3),
                    Expanded(
                      child: PrimaryButton(
                        key: GoldPathPatrolKeys.connectFF1Cancel,
                        text: 'Cancel',
                        onTap: _onCancel,
                        color: AppColor.white,
                        textColor: AppColor.primaryBlack,
                      ),
                    ),
                  ],
                ),
              ] else if (status != _ConnectFF1Status.portalIsSet) ...[
                PrimaryButton(
                  key: GoldPathPatrolKeys.connectFF1Cancel,
                  text: 'Cancel',
                  onTap: _onCancel,
                  color: AppColor.white,
                  textColor: AppColor.primaryBlack,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bluetoothNotAvailableView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error,
          size: LayoutConstants.iconSizeLarge * 2,
          color: AppColor.feralFileLightBlue,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          'Bluetooth is required for setup. Please turn it on to continue.',
          style: AppTypography.h2(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space5),
        PrimaryButton(
          text: 'Open Bluetooth Settings',
          onTap: () async {
            AppStructuredLog.logUiAction(
              logger: _log,
              action: 'open_bluetooth_settings',
            );
            await openAppSettings();
          },
        ),
      ],
    );
  }

  String _getTitleText(_ConnectFF1Status status) {
    switch (status) {
      case _ConnectFF1Status.connecting:
        return 'Connecting via Bluetooth...';
      case _ConnectFF1Status.stillConnecting:
        return 'Still connecting…';
      case _ConnectFF1Status.bluetoothOff:
        return 'Bluetooth is Off';
      case _ConnectFF1Status.error:
        return 'We couldn’t connect to FF1';
      case _ConnectFF1Status.success:
        return 'Connected to FF1';
      case _ConnectFF1Status.portalIsSet:
        return 'The FF1 is All Set';
    }
  }

  String _getBodyText(_ConnectFF1Status status) {
    switch (status) {
      case _ConnectFF1Status.connecting:
        return 'Keep your phone near FF1 and remain on this screen.';
      case _ConnectFF1Status.stillConnecting:
        return 'We’re still trying to reach your FF1 over Bluetooth.\n'
            'If this takes more than 15 seconds, you can cancel and try again.';
      case _ConnectFF1Status.bluetoothOff:
        return 'Turn on Bluetooth to connect to FF1.';
      case _ConnectFF1Status.error:
        return 'A few things to check:\n'
            '• Make sure your FF1 is powered on.\n'
            '• Keep your phone close to the device.\n'
            '• Check that Bluetooth is turned on.';
      case _ConnectFF1Status.success:
        return 'Connected to FF1 — ready to play art.';
      case _ConnectFF1Status.portalIsSet:
        return 'Your FF1 is already set up and connected. You can head to '
            'settings to make changes or check the status.';
    }
  }
}
