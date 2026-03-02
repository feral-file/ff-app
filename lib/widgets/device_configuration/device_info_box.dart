import 'dart:async';

import 'package:app/app/providers/ff1_device_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/domain/models/ff1/canvas_cast_request_reply.dart';
import 'package:app/domain/models/ff1/screen_orientation.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';

/// Device info box.
class DeviceInfoBox extends ConsumerWidget {
  /// Constructor.
  const DeviceInfoBox({
    required this.device,
    required this.deviceData,
    super.key,
  });

  /// Device.
  final FF1Device device;

  /// Device data.
  final FF1DeviceData deviceData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceStatus = deviceData.deviceStatus;
    final installedVersion = deviceStatus?.installedVersion;
    final branchName = (device.isReleaseBranch)
        ? ''
        : ' (${device.branchName})';
    final deviceId = device.deviceId;
    final connectedWifi = deviceStatus?.connectedWifi;

    final latestMetrics = ref.watch(ff1LatestDeviceRealtimeMetricsProvider);
    final resolution = latestMetrics?.screen?.sizeOnOrientation(
      deviceStatus?.screenRotation ?? ScreenOrientation.landscape,
    );
    final refreshRate = latestMetrics?.screen?.refreshRate;

    final isSleeping = deviceData.playerStatus?.isSleeping ?? false;
    final isConnected = deviceData.isConnected;

    const divider = Divider(
      height: 16,
      color: AppColor.auGreyBackground,
      thickness: 1,
    );

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColor.primaryBlack,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // connection status
          DeviceInfoItem(
            title: 'Connection Status:',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isConnected
                        ? isSleeping
                              ? Colors.grey
                              : Colors.green
                        : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isConnected
                        ? isSleeping
                              ? 'Sleeping'
                              : 'Connected'
                        : 'Device not connected',
                    style: AppTypography.body(context).white,
                  ),
                ),
              ],
            ),
          ),
          divider,

          // Device Id
          DeviceInfoItem(
            title: 'Device Id:',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    deviceId,
                    style: AppTypography.body(context).white.copyWith(
                      color: isConnected
                          ? AppColor.white
                          : AppColor.disabledColor,
                    ),
                  ),
                ),
                _copyButton(
                  context,
                  deviceId,
                ),
              ],
            ),
          ),
          divider,
          // software version
          DeviceInfoItem(
            title: 'Software Version',
            child: RichText(
              text: TextSpan(
                style: AppTypography.body(context).white.copyWith(
                  color: isConnected ? AppColor.white : AppColor.disabledColor,
                ),
                children: [
                  TextSpan(
                    text: (installedVersion ?? '-') + branchName,
                  ),
                ],
              ),
            ),
          ),
          divider,

          // WiFi Network
          // Check if the device is connected to WiFi
          // If not connected, show "Not connected" message
          // If connected, show the connected WiFi name
          if (deviceStatus != null) ...[
            DeviceInfoItem(
              title: 'Device Wifi Network',
              child: Text(
                connectedWifi ?? '-',
                style: AppTypography.body(context).white.copyWith(
                  color: isConnected ? AppColor.white : AppColor.disabledColor,
                ),
              ),
            ),
            divider,
          ],
          ...[
            DeviceInfoItem(
              title: 'Screen Resolution',
              child: Builder(
                builder: (context) {
                  return Text(
                    resolution == null
                        ? '--'
                        : '${resolution.width.toInt()} x ${resolution.height.toInt()}',
                    style: AppTypography.body(context).white.copyWith(
                      color: isConnected
                          ? AppColor.white
                          : AppColor.disabledColor,
                    ),
                  );
                },
              ),
            ),
            divider,
          ],
          DeviceInfoItem(
            title: 'Refresh Rate',
            child: Text(
              refreshRate == null ? '--' : '$refreshRate Hz',
              style: AppTypography.body(context).white.copyWith(
                color: isConnected ? AppColor.white : AppColor.disabledColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyButton(BuildContext context, String deviceId) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device Id copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
        unawaited(
          Clipboard.setData(ClipboardData(text: deviceId)),
        );
      },
      child: SvgPicture.asset(
        'assets/images/copy.svg',
        height: 16,
        width: 16,
        colorFilter: const ColorFilter.mode(
          AppColor.white,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

/// Device info item.
class DeviceInfoItem extends StatelessWidget {
  /// Constructor.
  const DeviceInfoItem({required this.child, required this.title, super.key});

  /// Title.
  final String title;

  /// Child.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.body(context).grey,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}
