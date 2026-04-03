import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/widgets/device_configuration/ffp_monitor_ddc_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Device Config section wrapper for FFP status.
///
/// Why this exists:
/// - `FfpMonitorDdcSection` intentionally renders nothing until the first
///   status payload is available.
/// - The Device Config screen should not show the "FFP Status" header/divider
///   without the actual status card underneath.
class FfpStatusSection extends ConsumerWidget {
  /// Creates the Device Config "FFP Status" section.
  const FfpStatusSection({
    required this.topicId,
    required this.isConnected,
    required this.isControllable,
    super.key,
  });

  /// Relayer topic id for FFP DDC status notifications.
  final String topicId;

  /// Whether the device is connected; disables the section when false.
  final bool isConnected;

  /// Whether the device is currently controllable (not sleeping, etc).
  final bool isControllable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isConnected || topicId.isEmpty) {
      return const SizedBox.shrink();
    }

    final async = ref.watch(ff1FfpDdcPanelStatusStreamProvider(topicId));
    final isReady = async.maybeWhen(
      data: (status) => status.hasData,
      orElse: () => false,
    );

    if (!isReady) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: LayoutConstants.pageHorizontalDefault,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FFP Status',
            style: AppTypography.body(context).white,
          ),
          SizedBox(height: LayoutConstants.space3),
          FfpMonitorDdcSection(
            key: ValueKey(topicId),
            topicId: topicId,
            isConnected: isConnected,
            isControllable: isControllable,
          ),
          SizedBox(height: LayoutConstants.space5),
        ],
      ),
    );
  }
}
