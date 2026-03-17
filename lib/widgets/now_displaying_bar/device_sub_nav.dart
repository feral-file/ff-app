import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_connection_providers.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Device sub-nav for switching between paired FF1 devices.
///
/// Matches old repo DeviceSubNav structure.
/// Uses connectedFF1DevicesProvider and setActiveFF1BluetoothDeviceProvider.
class DeviceSubNav extends ConsumerWidget {
  const DeviceSubNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectedDevicesAsync = ref.watch(connectedFF1DevicesProvider);
    final activeDeviceAsync = ref.watch(activeFF1BluetoothDeviceProvider);

    return connectedDevicesAsync.when(
      data: (devices) {
        if (devices.isEmpty) {
          return const SizedBox.shrink();
        }

        return activeDeviceAsync.when(
          data: (selectedDevice) {
            return SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: devices.asMap().entries.map((entry) {
                    final index = entry.key;
                    final device = entry.value;
                    return Row(
                      children: [
                        if (index > 0)
                          SizedBox(
                            width:
                                LayoutConstants.nowPlayingBarBottomDeviceNavGap,
                          ),
                        _DeviceNavItem(
                          device: device,
                          isSelected:
                              selectedDevice?.deviceId == device.deviceId,
                          onTap: () async {
                            if (selectedDevice?.deviceId == device.deviceId) {
                              return;
                            }
                            await ref.read(
                              setActiveFF1BluetoothDeviceProvider(
                                device.deviceId,
                              ).future,
                            );
                          },
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _DeviceNavItem extends StatelessWidget {
  const _DeviceNavItem({
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  final FF1Device device;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final baseStyle = ContentRhythm.controlLabel(context).copyWith(
      fontWeight: FontWeight.w700,
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: LayoutConstants.minTouchTarget,
        ),
        child: Center(
          child: Text(
            device.name,
            style: isSelected
                ? baseStyle.copyWith(color: PrimitivesTokens.colorsWhite)
                : baseStyle.copyWith(color: PrimitivesTokens.colorsGrey),
          ),
        ),
      ),
    );
  }
}
