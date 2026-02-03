import 'package:app/app/providers/ff1_connection_providers.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
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
      appBar: AppBar(
        title: const Text('Connected FF1 Devices'),
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
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Connected Devices',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan and connect a device to get started',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return _ConnectedDeviceCard(device: device);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) {
          log.severe('Error loading devices', error, stackTrace);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Error Loading Devices',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
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
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Header with device name and status
          Padding(
            padding: const EdgeInsets.all(16),
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Device ID: ${device.deviceId}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    isActive.when(
                      data: (active) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: active ? Colors.green[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          active ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color:
                                active ? Colors.green[700] : Colors.grey[700],
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
          const Divider(height: 1),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _DetailRow(
                  label: 'Bluetooth Remote ID',
                  value: device.remoteId,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Branch',
                  value: device.branchName,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Topic ID',
                  value: device.topicId ?? 'N/A',
                  isCopyable: true,
                ),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Cloud Connected',
                  value: device.hasCloudConnection ? 'Yes' : 'No',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
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
        title: Text(device.name),
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
            child: const Text('Close'),
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
        title: const Text('Disconnect Device?'),
        content: Text(
          'Remove WiFi connection from ${device.name}? The device will remain in your list but will need to reconnect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
                      content: Text('${device.name} disconnected'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }).catchError((Object error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              });
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  void _confirmForget(BuildContext context, WidgetRef ref, FF1Device device) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forget Device?'),
        content: Text(
          'Remove ${device.name} from your device list? You will need to reconnect it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
                      content: Text('${device.name} removed'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }).catchError((Object error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              });
            },
            child: const Text('Forget', style: TextStyle(color: Colors.red)),
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
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCopyable) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.copy,
                    size: 14,
                    color: Colors.blue[600],
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
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
