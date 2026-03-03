import 'dart:async';

import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/navigation_extensions.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/domain/models/models.dart';
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

enum _ConnectFF1Status {
  connecting,
  stillConnecting,
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
    this.ff1DeviceInfo,
  });

  /// Bluetooth device
  final BluetoothDevice device;

  /// FF1 device
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
  late final ConnectFF1Notifier _connectFF1Notifier;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    _connectFF1Notifier = ref.read(connectFF1Provider.notifier);

    // Start connection flow using the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        _connectFF1Notifier.connectBle(widget.payload.device),
      );
    });
  }

  @override
  void dispose() {
    // Cancel connection if still in progress
    _connectFF1Notifier.cancelConnection();
    super.dispose();
  }

  /// Map provider state to UI status
  _ConnectFF1Status _getStatusFromProviderState(ConnectFF1State? state) {
    if (state == null) {
      return _ConnectFF1Status.connecting;
    }

    return switch (state) {
      ConnectFF1Connecting() => _ConnectFF1Status.connecting,
      ConnectFF1StillConnecting() => _ConnectFF1Status.stillConnecting,
      ConnectFF1Connected() =>
        state.portalIsSet
            ? _ConnectFF1Status.portalIsSet
            : _ConnectFF1Status.success,
      ConnectFF1Error() => _ConnectFF1Status.error,
      _ => _ConnectFF1Status.connecting,
    };
  }

  Future<void> _startConnectFlow() async {
    _startTime = DateTime.now();
    _log.info('[ConnectFF1Page] Start connecting to FF1');
    await _connectFF1Notifier.connectBle(widget.payload.device);
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
    _connectFF1Notifier.cancelConnection();
    try {
      await widget.payload.device.disconnect();
    } on Exception catch (e) {
      _log.info('[ConnectFF1Page] Error while disconnecting: $e');
    }

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(connectFF1Provider);
    final status = setupState.maybeWhen(
      data: _getStatusFromProviderState,
      loading: () => _ConnectFF1Status.connecting,
      error: (error, stack) => _ConnectFF1Status.error,
      orElse: () => _ConnectFF1Status.connecting,
    );

    // Listen for state changes to handle callbacks
    ref.listen<AsyncValue<ConnectFF1State>>(connectFF1Provider, (
      previous,
      next,
    ) {
      next.whenData((state) async {
        if (state is ConnectFF1Connected) {
          _recordDuration(success: true);
          if (state.isConnectedToInternet) {
            await ref.read(
              addFF1BluetoothDeviceProvider(state.ff1device).future,
            );

            if (state.portalIsSet) {
              // Portal is set, show portal is set view
            } else {
              if (context.mounted) {
                unawaited(
                  ref.read(onboardingActionsProvider).completeOnboarding(),
                );
                context.popUntil(Routes.startSetupFf1);
                // TODO: Navigate to Device config instead
                unawaited(
                  context.push(Routes.home),
                );
              }
            }
          } else {
            // No internet connection, navigate to scan wifi networks page
            context.replace(
              Routes.scanWifiNetworks,
              extra: ScanWifiNetworkPagePayload(
                device: state.ff1device,
              ),
            );
          }
        } else if (state is ConnectFF1Error) {
          _recordDuration(success: false);

          if (state.exception is FF1ResponseError) {
            final exception = state.exception as FF1ResponseError;
            await UIHelper.showInfoDialog(
              context,
              exception.title,
              exception.message,
              closeButton: exception.shouldShowSupport ? 'Contact support' : '',
              onClose: exception.shouldShowSupport
                  ? () => unawaited(UIHelper.showCustomerSupport(context))
                  : null,
            );
          } else {
            await UIHelper.showInfoDialog(
              context,
              'Connect failed',
              state.exception.toString(),
              closeButton: 'Contact support',
              onClose: () async {
                unawaited(
                  UIHelper.showCustomerSupport(context),
                );
              },
            );
          }
        }
      });
    });

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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (status != _ConnectFF1Status.error) ...[
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
                    ] else ...[
                      Icon(
                        Icons.error,
                        size: LayoutConstants.iconSizeLarge * 2,
                        color: PrimitivesTokens.colorsLightBlue,
                      ),
                      SizedBox(
                        height: LayoutConstants.space4,
                      ),
                    ],
                    Align(
                      alignment: status != _ConnectFF1Status.error
                          ? Alignment.centerLeft
                          : Alignment.center,
                      child: Column(
                        crossAxisAlignment: status != _ConnectFF1Status.error
                            ? CrossAxisAlignment.start
                            : CrossAxisAlignment.center,
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
                                // TODO: Navigate to Device config instead
                                unawaited(
                                  ref
                                      .read(onboardingActionsProvider)
                                      .completeOnboarding(),
                                );
                                context.go(Routes.home);
                              },
                              text: 'Start using the app',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (status == _ConnectFF1Status.error) ...[
                SizedBox(height: LayoutConstants.space6),
                Row(
                  children: [
                    Expanded(
                      child: PrimaryButton(
                        text: 'Try Again',
                        onTap: _startConnectFlow,
                        color: AppColor.white,
                        textColor: AppColor.primaryBlack,
                      ),
                    ),
                    SizedBox(width: LayoutConstants.space3),
                    Expanded(
                      child: PrimaryButton(
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

  String _getTitleText(_ConnectFF1Status status) {
    switch (status) {
      case _ConnectFF1Status.connecting:
        return 'Connecting via Bluetooth...';
      case _ConnectFF1Status.stillConnecting:
        return 'Still connecting…';
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
        return 'We’re still trying to reach your FF1 over Bluetooth.\nIf this takes more than 15 seconds, you can cancel and try again.';
      case _ConnectFF1Status.error:
        return 'A few things to check:\n• Make sure your FF1 is powered on.\n• Keep your phone close to the device.\n• Check that Bluetooth is turned on.';
      case _ConnectFF1Status.success:
        return 'Connected to FF1 — ready to play art.';
      case _ConnectFF1Status.portalIsSet:
        return 'Your FF1 is already set up and connected. You can head to settings to make changes or check the status.';
    }
  }
}
