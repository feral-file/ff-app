import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Switch device button.
class SwitchDeviceButton extends ConsumerWidget {
  /// Constructor.
  const SwitchDeviceButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get saved devices and active device from Riverpod
    final connectedDevicesAsync = ref.watch(allFF1BluetoothDevicesProvider);
    final activeDeviceAsync = ref.watch(activeFF1BluetoothDeviceProvider);

    return activeDeviceAsync.maybeWhen(
      data: (activeDevice) {
        return connectedDevicesAsync.maybeWhen(
          data: (devices) {
            // If there are less than 2 devices, don't show the switcher
            if (devices.length < 2) {
              return const SizedBox.shrink();
            }

            return PopupMenuButton<FF1Device>(
              tooltip: 'Switch Device',
              offset: const Offset(0, 40),
              onSelected: (device) async {
                if (activeDevice?.deviceId == device.deviceId) {
                  return;
                }

                // Set as active device
                await ref.read(
                  setActiveFF1BluetoothDeviceProvider(
                    device.deviceId,
                  ).future,
                );
              },
              itemBuilder: (context) {
                return devices.map((device) {
                  final isSelected = device.deviceId == activeDevice?.deviceId;
                  return PopupMenuItem<FF1Device>(
                    value: device,
                    child: Row(
                      children: [
                        Icon(
                          Icons.tv,
                          color: isSelected
                              ? AppColor.white
                              : AppColor.white.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            device.name,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColor.white
                                  : AppColor.white.withValues(alpha: 0.9),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle,
                            color: AppColor.white,
                            size: 16,
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList();
              },
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.devices,
                  color: AppColor.white,
                  size: 24,
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
