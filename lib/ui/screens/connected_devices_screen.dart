import 'package:app/app/providers/ff1_connection_providers.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Screen displaying connected FF1 devices with their details
class ConnectedDevicesScreen extends ConsumerWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectedDevicesAsync = ref.watch(connectedFF1DevicesProvider);
    final log = Logger('ConnectedDevicesScreen');

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: AppBar(
        backgroundColor: AppColor.auGreyBackground,
        title: Text(
          'Connected devices',
          style: AppTypography.h4(context).white,
        ),
        elevation: 0,
      ),
      body: connectedDevicesAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices,
                    size: LayoutConstants.space16,
                    color: AppColor.auQuickSilver,
                  ),
                  SizedBox(height: LayoutConstants.space4),
                  Text(
                    'No Connected Devices',
                    style: AppTypography.h3(context).white,
                  ),
                  SizedBox(height: LayoutConstants.space2),
                  Text(
                    'Scan and connect a device to get started',
                    style: AppTypography.body(context).grey,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(LayoutConstants.space4),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return _ConnectedDeviceCard(device: device);
            },
          );
        },
        loading: () => const LoadingView(),
        error: (error, stackTrace) {
          log.severe('Error loading devices', error, stackTrace);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: LayoutConstants.space12,
                  color: AppColor.error,
                ),
                SizedBox(height: LayoutConstants.space4),
                Text(
                  'Error Loading Devices',
                  style: AppTypography.h3(context).white,
                ),
                SizedBox(height: LayoutConstants.space2),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: LayoutConstants.space6),
                  child: Text(
                    'We couldn’t load devices. Try again.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(context).grey,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Card widget displaying a single connected device
class _ConnectedDeviceCard extends ConsumerWidget {
  const _ConnectedDeviceCard({required this.device});

  final FF1Device device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(activeFF1BluetoothDeviceProvider).whenData(
          (activeDevice) => activeDevice?.deviceId == device.deviceId,
        );

    return Card(
      margin: EdgeInsets.only(bottom: LayoutConstants.space3),
      child: Column(
        children: [
          // Header with device name and status
          Padding(
            padding: EdgeInsets.all(LayoutConstants.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            device.name,
                            style: AppTypography.h4(context).black,
                          ),
                          SizedBox(height: LayoutConstants.space1),
                          Text(
                            'Device ID: ${device.deviceId}',
                            style: AppTypography.bodySmall(context).grey,
                          ),
                        ],
                      ),
                    ),
                    isActive.when(
                      data: (active) => Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: LayoutConstants.space3,
                          vertical: LayoutConstants.space1,
                        ),
                        decoration: BoxDecoration(
                          color: active ? Colors.green[100] : Colors.grey[200],
                          borderRadius:
                              BorderRadius.circular(LayoutConstants.space5),
                        ),
                        child: Text(
                          active ? 'Active' : 'Inactive',
                          style: AppTypography.captionBold(context).copyWith(
                            color: active ? Colors.green[700] : Colors.grey[700],
                          ),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(
            height: LayoutConstants.dividerThickness,
            thickness: LayoutConstants.dividerThickness,
          ),
          // Details
          Padding(
            padding: EdgeInsets.all(LayoutConstants.space4),
            child: Column(
              children: [
                _DetailRow(
                  label: 'Bluetooth Remote ID',
                  value: device.remoteId,
                ),
                SizedBox(height: LayoutConstants.space3),
                _DetailRow(
                  label: 'Branch',
                  value: device.branchName,
                ),
                SizedBox(height: LayoutConstants.space3),
                _DetailRow(
                  label: 'Topic ID',
                  value: device.topicId ?? 'N/A',
                  isCopyable: true,
                ),
                SizedBox(height: LayoutConstants.space3),
                _DetailRow(
                  label: 'Cloud Connected',
                  value: device.hasCloudConnection ? 'Yes' : 'No',
                ),
              ],
            ),
          ),
          Divider(
            height: LayoutConstants.dividerThickness,
            thickness: LayoutConstants.dividerThickness,
          ),
          // Actions
          Padding(
            padding: EdgeInsets.all(LayoutConstants.space3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ActionButton(
                  icon: Icons.info_outline,
                  label: 'Details',
                  onPressed: () {
                    _showDeviceDetails(context, device);
                  },
                ),
                _ActionButton(
                  icon: Icons.link_off,
                  label: 'Disconnect',
                  onPressed: () {
                    _confirmDisconnect(context, ref, device);
                  },
                ),
                _ActionButton(
                  icon: Icons.delete_outline,
                  label: 'Forget',
                  isDestructive: true,
                  onPressed: () {
                    _confirmForget(context, ref, device);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetails(BuildContext context, FF1Device device) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColor.primaryBlack,
        title: Text(
          device.name,
          style: AppTypography.h4(context).white,
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailText('Device ID', device.deviceId),
              _DetailText('Remote ID', device.remoteId),
              _DetailText('Branch', device.branchName),
              _DetailText('Topic ID', device.topicId ?? 'Not set'),
              _DetailText(
                'Cloud Connected',
                device.hasCloudConnection ? 'Yes' : 'No',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: AppTypography.body(context).white,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDisconnect(
    BuildContext context,
    WidgetRef ref,
    FF1Device device,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColor.primaryBlack,
        title: Text(
          'Disconnect device?',
          style: AppTypography.h4(context).white,
        ),
        content: Text(
          'Remove WiFi connection from ${device.name}? The device will remain in your list but will need to reconnect.',
          style: AppTypography.body(context).grey,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.body(context).grey,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(disconnectFF1DeviceProvider(device.deviceId).future)
                  .then((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${device.name} disconnected',
                        style: AppTypography.body(context).white,
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }).catchError((Object error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'We couldn’t disconnect the device. Try again.',
                        style: AppTypography.body(context).white,
                      ),
                      backgroundColor: AppColor.error,
                    ),
                  );
                }
              });
            },
            child: Text(
              'Disconnect',
              style: AppTypography.body(context).white,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmForget(BuildContext context, WidgetRef ref, FF1Device device) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColor.primaryBlack,
        title: Text(
          'Forget device?',
          style: AppTypography.h4(context).white,
        ),
        content: Text(
          'Remove ${device.name} from your device list? You will need to reconnect it later.',
          style: AppTypography.body(context).grey,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: AppTypography.body(context).grey,
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(forgetFF1DeviceProvider(device.deviceId).future)
                  .then((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${device.name} removed',
                        style: AppTypography.body(context).white,
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }).catchError((Object error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'We couldn’t remove the device. Try again.',
                        style: AppTypography.body(context).white,
                      ),
                      backgroundColor: AppColor.error,
                    ),
                  );
                }
              });
            },
            child: Text(
              'Forget',
              style: AppTypography.body(context).white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple detail row widget
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isCopyable = false,
  });

  final String label;
  final String value;
  final bool isCopyable;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: LayoutConstants.detailLabelWidth,
          child: Text(
            label,
            style: AppTypography.bodySmall(context).grey,
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: AppTypography.bodySmall(context).black,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCopyable) ...[
                SizedBox(width: LayoutConstants.space2),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Copied to clipboard',
                          style: AppTypography.body(context).white,
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.copy,
                    size: LayoutConstants.iconSizeSmall,
                    color: AppColor.feralFileLightBlue,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Detail text widget for dialog
class _DetailText extends StatelessWidget {
  const _DetailText(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.captionBold(context).grey,
        ),
        SizedBox(height: LayoutConstants.space1),
        Text(
          value,
          style: AppTypography.bodySmall(context).white,
        ),
        SizedBox(height: LayoutConstants.space4),
      ],
    );
  }
}

/// Action button widget
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red[600] : Colors.blue[600];

    return GestureDetector(
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: LayoutConstants.iconSizeLarge),
          SizedBox(height: LayoutConstants.space1),
          Text(
            label,
            style: AppTypography.caption(context).copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
