import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/send_log_provider.dart';
import 'package:app/app/routing/navigation_extensions.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control_verifier.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/scan_wifi_network_screen.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:app/widgets/common/touch_target.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger('OptionsButton');

/// Options button.
class OptionsButton extends ConsumerWidget {
  /// Constructor.
  const OptionsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDeviceAsync = ref.watch(activeFF1BluetoothDeviceProvider);

    return activeDeviceAsync.maybeWhen(
      data: (device) {
        if (device == null) {
          return const SizedBox.shrink();
        }

        return Container(
          padding:
              const EdgeInsets.all(
                8,
              ).copyWith(
                left: 14,
                right: LayoutConstants.pageHorizontalDefault,
              ),
          child: GestureDetector(
            onTap: () {
              _showOptions(context, ref, device);
            },
            child: TouchTarget(
              minSize: LayoutConstants.minTouchTarget,
              child: SvgPicture.asset(
                'assets/images/more_circle.svg',
                width: 22,
                colorFilter: const ColorFilter.mode(
                  AppColor.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref, FF1Device device) {
    // Get active device and WiFi status from providers
    final isDeviceConnected = ref.read(ff1DeviceConnectedProvider);

    final control = ref.read(ff1WifiControlProvider);
    final topicId = device.topicId;

    // Read version info so the update dialog can display current/latest.
    final deviceStatus = ref.read(ff1CurrentDeviceStatusProvider);

    final options = [
      if (isDeviceConnected) ...[
        OptionItem(
          title: 'Power Off',
          icon: const Icon(
            Icons.power_settings_new,
            size: 24,
          ),
          onTap: () => unawaited(
            _onPowerOffSelected(
              context,
              control,
              topicId,
            ),
          ),
        ),
        OptionItem(
          title: 'Restart',
          icon: const Icon(
            Icons.restart_alt,
            size: 24,
          ),
          onTap: () => unawaited(
            _onRebootSelected(
              context,
              control,
              topicId,
            ),
          ),
        ),
        OptionItem(
          title: 'Update FF1',
          icon: const Icon(Icons.system_update_alt),
          onTap: () => unawaited(
            _onUpdateFirmwareSelected(
              context,
              ref,
              control,
              device,
              deviceStatus,
            ),
          ),
        ),
      ],
      OptionItem(
        title: 'Send Log',
        icon: const Icon(Icons.help),
        onTap: () => unawaited(
          _onSendLogSelected(
            context,
            ref,
            device,
          ),
        ),
      ),
      OptionItem(
        title: 'Factory Reset',
        icon: const Icon(Icons.factory),
        onTap: () => unawaited(
          _onFactoryResetSelected(
            context,
            ref,
            control,
            device,
          ),
        ),
      ),
      OptionItem(
        title: 'FF1 Guide',
        icon: const Icon(Icons.book),
        onTap: () async {
          await _onViewDocumentationSelected();
        },
      ),
      OptionItem(
        title: 'Configure Wi-Fi',
        icon: const Icon(Icons.wifi),
        onTap: () => _onConfigureWiFiSelected(context, device),
      ),
      OptionItem.emptyOptionItem,
    ];

    unawaited(
      UIHelper.showDrawerAction(
        context,
        options: options,
        title: device.name,
      ),
    );
  }

  Future<void> _onPowerOffSelected(
    BuildContext context,
    FF1WifiControl control,
    String topicId,
  ) async {
    final result = await UIHelper.showCenterDialog(
      context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Power Off',
            style: AppTypography.h2(context).bold.white,
          ),
          SizedBox(height: LayoutConstants.space4),
          Text(
            'Are you sure you want to power off the device?',
            style: AppTypography.body(context).white,
          ),
          SizedBox(height: LayoutConstants.space10),
          Row(
            children: [
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Cancel',
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () {
                    Navigator.pop(context, false);
                  },
                ),
              ),
              SizedBox(width: LayoutConstants.space4),
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Power Off',
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () async {
                    try {
                      await control.shutdown(topicId: topicId);
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    } on Exception catch (e) {
                      _log.warning('[Power Off] Failed: $e');
                      if (context.mounted) {
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

    if (result is Exception || result is Error) {
      if (context.mounted) {
        await UIHelper.showInfoDialog(
          context,
          'Power Off Failed',
          'Something went wrong while trying to power off the device. $result',
        );
      }
    }
  }

  Future<void> _onRebootSelected(
    BuildContext context,
    FF1WifiControl control,
    String topicId,
  ) async {
    final result = await UIHelper.showCenterDialog(
      context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restart',
            style: AppTypography.h2(context).bold.white,
          ),
          SizedBox(height: LayoutConstants.space4),
          Text(
            'Are you sure you want to restart the device?',
            style: AppTypography.body(context).white,
          ),
          SizedBox(height: LayoutConstants.space10),
          Row(
            children: [
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Cancel',
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () {
                    Navigator.pop(context, false);
                  },
                ),
              ),
              SizedBox(width: LayoutConstants.space4),
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Restart',
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () async {
                    try {
                      await control.reboot(topicId: topicId);
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    } on Exception catch (e) {
                      _log.warning('[Restart] Failed: $e');
                      if (context.mounted) {
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

    if (result is Exception || result is Error) {
      if (context.mounted) {
        await UIHelper.showInfoDialog(
          context,
          'Restart Failed',
          'Something went wrong while trying to restart the device. $result',
        );
      }
    }
  }

  Future<void> _onSendLogSelected(
    BuildContext context,
    WidgetRef ref,
    FF1Device device,
  ) async {
    final outcome = await ref.read(sendLogProvider.notifier).send(device);
    if (!context.mounted) return;

    switch (outcome) {
      case SendLogNotConfigured():
        await UIHelper.showDialog<void>(
          context,
          'Not configured',
          Text(
            'Send Log is not configured on this build.',
            style: AppTypography.body(context).white,
          ),
        );
      case SendLogSuccess():
        await UIHelper.showDialog<void>(
          context,
          'Log sent',
          Text(
            'Your log has been sent to support. Thank you for your help!',
            style: AppTypography.body(context).white,
          ),
        );
      case SendLogFailure():
        await UIHelper.showDialog<void>(
          context,
          'Failed to send log',
          Text(
            'Failed to send log to support. Please try again.',
            style: AppTypography.body(context).white,
          ),
        );
    }
  }

  Future<void> _onFactoryResetSelected(
    BuildContext context,
    WidgetRef ref,
    FF1WifiControl control,
    FF1Device device,
  ) async {
    final result = await UIHelper.showCenterDialog(
      context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Factory Reset',
            style: AppTypography.h2(context).bold.white,
          ),
          SizedBox(height: LayoutConstants.space4),
          Text(
            'Are you sure you want to reset the device to factory settings? '
            'This will erase all data and cannot be undone.',
            style: AppTypography.body(context).white,
          ),
          SizedBox(height: LayoutConstants.space10),
          Row(
            children: [
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Cancel',
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () {
                    Navigator.pop(context, false);
                  },
                ),
              ),
              SizedBox(width: LayoutConstants.space4),
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Reset',
                  textColor: AppColor.white,
                  borderColor: AppColor.white,
                  color: Colors.transparent,
                  onTap: () async {
                    try {
                      var success = false;

                      if (device.topicId.isNotEmpty) {
                        try {
                          _log.info('[Factory Reset] Attempting via WiFi');
                          final response = await control.factoryReset(
                            topicId: device.topicId,
                          );
                          final okFlag = ff1CommandResponseOkFlag(response);
                          success = okFlag ?? ff1CommandResponseIsOk(response);
                          if (!success) {
                            _log.warning(
                              '[Factory Reset] WiFi returned unsuccessful '
                              'response, fallback to BLE',
                            );
                          }
                        } on Exception catch (e) {
                          _log.warning(
                            '[Factory Reset] WiFi error: $e, '
                            'falling back to BLE',
                          );
                        }
                      }

                      if (!success) {
                        _log.info('[Factory Reset] Attempting via Bluetooth');
                        await ref
                            .read(ff1ControlProvider)
                            .factoryReset(blDevice: device.toBluetoothDevice());
                        success = true;
                      }

                      if (context.mounted) {
                        Navigator.pop(context, success);
                      }
                    } on Exception catch (e) {
                      _log.warning('[Factory Reset] Failed: $e');
                      if (context.mounted) {
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

    if (result is bool) {
      if (result) {
        if (context.mounted) {
          context.popUntil(Routes.home);
          await UIHelper.showInfoDialog(
            context,
            'Restoring Factory Defaults',
            'The device is now restoring to factory settings. It may take '
            'some time to complete. Please keep the FF1 powered on and wait '
            'until the reset is finished.',
            closeButton: 'Go Back',
            onClose: () {
              context.pop();
            },
          );
        }
      }
    } else if (result != null) {
      if (context.mounted) {
        await UIHelper.showInfoDialog(
          context,
          'Factory Reset Failed',
          'Something went wrong while trying to restore the device to '
          'factory settings. $result',
        );
      }
    }
  }

  Future<void> _onUpdateFirmwareSelected(
    BuildContext context,
    WidgetRef ref,
    FF1WifiControl control,
    FF1Device device,
    FF1DeviceStatus? deviceStatus,
  ) async {
    final topicId = device.topicId;
    // Build version detail line for the dialog only when version info is known.
    final installed = deviceStatus?.installedVersion;
    final latest = deviceStatus?.latestVersion;
    final hasVersionInfo = installed != null && latest != null;
    final isUpToDate = hasVersionInfo && installed == latest;

    final result = await UIHelper.showCenterDialog(
      context,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update FF1',
            style: AppTypography.h2(context).bold.white,
          ),
          SizedBox(height: LayoutConstants.space4),
          if (isUpToDate)
            Text(
              'Your FF1 is already on the latest version ($installed).',
              style: AppTypography.body(context).white,
            )
          else ...[
            Text(
              '''
Update your FF1 to the latest version. Keep the device connected and powered on during the update. It will restart automatically when the update is complete.''',
              style: AppTypography.body(context).white,
            ),
          ],
          SizedBox(height: LayoutConstants.space10),
          Row(
            children: [
              Expanded(
                child: PrimaryAsyncButton(
                  text: 'Cancel',
                  textColor: AppColor.white,
                  color: Colors.transparent,
                  borderColor: AppColor.white,
                  onTap: () {
                    Navigator.pop(context, false);
                  },
                ),
              ),
              if (!isUpToDate) ...[
                SizedBox(width: LayoutConstants.space4),
                Expanded(
                  child: PrimaryAsyncButton(
                    text: 'Update',
                    textColor: AppColor.white,
                    color: Colors.transparent,
                    borderColor: AppColor.white,
                    onTap: () async {
                      try {
                        var success = false;

                        if (topicId.isNotEmpty) {
                          try {
                            _log.info(
                              '[Update Firmware] Attempting via WiFi',
                            );
                            final response = await control
                                .updateToLatestVersion(
                                  topicId: topicId,
                                );
                            final okFlag = ff1CommandResponseOkFlag(response);
                            success =
                                okFlag ?? ff1CommandResponseIsOk(response);
                            if (!success) {
                              _log.warning(
                                '[Update Firmware] WiFi returned '
                                'unsuccessful response, falling back to BLE',
                              );
                            }
                          } on Exception catch (e) {
                            _log.warning(
                              '[Update Firmware] WiFi error: $e, '
                              'falling back to BLE',
                            );
                          }
                        }

                        if (!success) {
                          _log.info(
                            '[Update Firmware] Attempting via Bluetooth',
                          );
                          await ref
                              .read(ff1ControlProvider)
                              .updateToLatestVersion(
                                blDevice: device.toBluetoothDevice(),
                              );
                          success = true;
                        }

                        if (context.mounted) {
                          Navigator.pop(context, success);
                        }
                      } on Exception catch (e) {
                        _log.warning('[Update Firmware] Failed: $e');
                        if (context.mounted) {
                          Navigator.pop(context, e);
                        }
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (result is bool && result) {
      if (context.mounted) {
        await UIHelper.showInfoDialog(
          context,
          'Update Started',
          'The FF1 is now downloading and installing the latest firmware. '
          'It will restart automatically when the update is complete.',
          closeButton: 'OK',
          onClose: () {
            context.pop();
          },
        );
      }
    } else if (result is Exception || result is Error) {
      if (context.mounted) {
        await UIHelper.showInfoDialog(
          context,
          'Update Failed',
          'Something went wrong while trying to start the update. $result',
        );
      }
    }
  }

  Future<void> _onViewDocumentationSelected() async {
    const url = 'https://docs.feralfile.com/ff1?from=app';
    final uri = Uri.parse(url);
    final didLaunch = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!didLaunch) {
      _log.warning('Failed to open documentation URL: $url');
    }
  }

  Future<void> _onConfigureWiFiSelected(
    BuildContext context,
    FF1Device device,
  ) async {
    await context.push(
      Routes.scanWifiNetworks,
      extra: ScanWifiNetworkPagePayload(
        device: device,
      ),
    );
  }
}
