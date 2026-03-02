import 'dart:async';

import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/routing/navigation_extensions.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/config/app_config.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/scan_wifi_network_screen.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/buttons/primary_button.dart';
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
            child: SvgPicture.asset(
              'assets/images/more_circle.svg',
              width: 22,
              colorFilter: const ColorFilter.mode(
                AppColor.white,
                BlendMode.srcIn,
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

    final options = [
      if (isDeviceConnected)
        OptionItem(
          title: 'Power Off',
          icon: const Icon(
            Icons.power_settings_new,
            size: 24,
          ),
          onTap: () {
            _onPowerOffSelected(context, control, topicId);
          },
        ),
      // reboot
      if (isDeviceConnected)
        OptionItem(
          title: 'Restart',
          icon: const Icon(
            Icons.restart_alt,
            size: 24,
          ),
          onTap: () {
            _onRebootSelected(
              context,
              control,
              topicId,
            );
          },
        ),
      OptionItem(
        title: 'Send Log',
        icon: const Icon(Icons.help),
        onTap: () async {
          await _onSendLogSelected(context, ref, device);
        },
      ),
      OptionItem(
        title: 'Factory Reset',
        icon: const Icon(Icons.factory),
        onTap: () => _onFactoryResetSelected(context, ref, control, device),
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

  void _onPowerOffSelected(
    BuildContext context,
    FF1WifiControl control,
    String topicId,
  ) {
    unawaited(
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColor.primaryBlack,
          title: Text(
            'Power Off',
            style: AppTypography.body(context).bold.white,
          ),
          content: Text(
            'Are you sure you want to power off the device?',
            style: AppTypography.body(context).white,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: AppTypography.body(context).white),
            ),
            TextButton(
              onPressed: () async {
                await control.shutdown(topicId: topicId);
                if (context.mounted) {
                  context.pop();
                }
              },
              child: Text('OK', style: AppTypography.body(context).white),
            ),
          ],
        ),
      ),
    );
  }

  void _onRebootSelected(
    BuildContext context,
    FF1WifiControl control,
    String topicId,
  ) {
    unawaited(
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColor.primaryBlack,
          title: Text(
            'Restart',
            style: AppTypography.body(context).bold.white,
          ),
          content: Text(
            'Are you sure you want to restart the device?',
            style: AppTypography.body(context).white,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: AppTypography.body(context).white),
            ),
            TextButton(
              onPressed: () async {
                await control.reboot(topicId: topicId);
                if (context.mounted) {
                  context.pop();
                }
              },
              child: Text('OK', style: AppTypography.body(context).white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSendLogSelected(
    BuildContext context,
    WidgetRef ref,
    FF1Device device,
  ) async {
    try {
      final control = ref.read(ff1WifiControlProvider);
      final bleControl = ref.read(ff1ControlProvider);
      const userId = 'user-id';
      final apiKey = AppConfig.ff1RelayerApiKey;
      var success = false;

      if (device.topicId.isNotEmpty) {
        try {
          _log.info('[Send Log] Attempting via WiFi');
          final response = await control.sendLog(
            topicId: device.topicId,
            userId: userId,
            title: device.name,
            apiKey: apiKey,
          );
          success = _isCommandSuccessful(response);
          if (!success) {
            _log.warning(
              '[Send Log] WiFi returned unsuccessful response, fallback to BLE',
            );
          }
        } catch (e) {
          _log.warning('[Send Log] WiFi error: $e, falling back to BLE');
        }
      }

      if (!success) {
        _log.info('[Send Log] Attempting via Bluetooth');
        await bleControl.sendLog(
          blDevice: device.toBluetoothDevice(),
          userId: userId,
          title: device.name,
          apiKey: apiKey,
        );
        success = true;
      }

      if (!context.mounted) {
        return;
      }

      if (success) {
        await UIHelper.showDialog<void>(
          context,
          'Log sent',
          Text(
            'Your log has been sent to support. Thank you for your help!',
            style: AppTypography.body(context).white,
          ),
        );
      } else {
        await UIHelper.showDialog<void>(
          context,
          'Failed to send log',
          Text(
            'The FF1 failed to send log to support.',
            style: AppTypography.body(context).white,
          ),
        );
      }
    } catch (e) {
      _log.warning('Error sending log: $e');
      if (!context.mounted) {
        return;
      }
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
            style: AppTypography.body(context).bold.white,
          ),
          const SizedBox(height: 16),
          Text(
            'Are you sure you want to reset the device to factory settings? This will erase all data and cannot be undone.',
            style: AppTypography.body(context).white,
          ),
          const SizedBox(height: 36),
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
              const SizedBox(width: 16),
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
                          success = _isCommandSuccessful(response);
                          if (!success) {
                            _log.warning(
                              '[Factory Reset] WiFi returned unsuccessful response, fallback to BLE',
                            );
                          }
                        } catch (e) {
                          _log.warning(
                            '[Factory Reset] WiFi error: $e, falling back to BLE',
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
                    } catch (e) {
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
            'The device is now restoring to factory settings. It may take some time to complete. Please keep the FF1 powered on and wait until the reset is finished.',
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
          'Something went wrong while trying to restore the device to factory settings. $result',
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

  bool _isCommandSuccessful(FF1CommandResponse response) {
    final dataOk = response.data?['ok'];
    if (dataOk is bool) {
      return dataOk;
    }
    final normalizedStatus = response.status?.toLowerCase();
    return normalizedStatus == null ||
        normalizedStatus == 'ok' ||
        normalizedStatus == 'success';
  }
}
