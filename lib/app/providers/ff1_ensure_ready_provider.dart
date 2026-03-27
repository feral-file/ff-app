// ignore_for_file: public_member_api_docs // Internal provider models.

import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/app/providers/version_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:app/domain/models/ff1_error.dart';
import 'package:app/infra/services/version_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// After any async gap, [FutureProvider.autoDispose] may dispose this provider
/// (navigation away, new family params, or no listeners). Using [Ref.read]
/// after disposal is treated as user-visible cancellation.
void _throwIfRefUnmounted(Ref ref) {
  if (!ref.mounted) {
    throw const FF1ConnectionCancelledError();
  }
}

class FF1EnsureReadyParams {
  const FF1EnsureReadyParams({
    required this.blDevice,
    required this.deviceInfo,
    required this.shouldContinue,
  });

  final BluetoothDevice blDevice;
  final FF1DeviceInfo deviceInfo;
  final bool Function() shouldContinue;

  void assertShouldContinue() {
    if (!shouldContinue()) {
      throw const FF1ConnectionCancelledError();
    }
  }
}

class FF1EnsureReadyResult {
  const FF1EnsureReadyResult({
    required this.ff1Device,
    required this.portalIsSet,
    required this.isConnectedToInternet,
  });

  final FF1Device ff1Device;
  final bool portalIsSet;
  final bool isConnectedToInternet;
}

/// Flow 3: given [FF1DeviceInfo], ensure the device is \"ready\" for config.
///
/// This preserves the legacy decision tree:
/// - internet=false → needs Wi‑Fi
/// - internet=true & topicId present → portalIsSet=true (also hides pairing QR)
/// - internet=true & topicId missing → call keepWifi to obtain topicId
///
/// Version compatibility check is executed before readiness decisions.
/// If the service indicates `needUpdateApp`, returns `null` and allows the
/// caller/orchestrator to keep the current UX (dialog already shown by service).
///
/// [autoDispose]: [FF1EnsureReadyParams] embeds a per-attempt
/// [FF1EnsureReadyParams.shouldContinue] closure without value equality, so
/// each connect attempt is a distinct family key. Auto-dispose drops completed
/// instances instead of retaining them for the container lifetime.
// ignore: specify_nonobvious_property_types
final ff1EnsureReadyProvider = FutureProvider.autoDispose
    .family<FF1EnsureReadyResult?, FF1EnsureReadyParams>((
      ref,
      params,
    ) async {
      // Without this, autoDispose can drop the provider after an await while
      // nothing watches this family (ConnectFF1Notifier only awaits `.future`),
      // so [ref.mounted] becomes false and we spuriously throw
      // [FF1ConnectionCancelledError] after e.g. [showPairingQRCode].
      final keepAliveLink = ref.keepAlive();
      try {
        // Ensure cancellation can surface through async boundary consistently.
        await Future<void>.value();
        _throwIfRefUnmounted(ref);
        params.assertShouldContinue();
        final info = params.deviceInfo;

        final versionService = ref.read(versionServiceProvider);
        final compatibility = await versionService
            .checkDeviceVersionCompatibility(
              branchName: info.branchName,
              deviceVersion: info.version,
            );
        _throwIfRefUnmounted(ref);
        params.assertShouldContinue();
        if (compatibility == VersionCompatibilityResult.needUpdateApp) {
          // Legacy: VersionService shows a dialog; connect flow does not emit
          // Connected here.
          return null;
        }

        var ff1Device = FF1Device.fromBluetoothDeviceAndDeviceInfo(
          params.blDevice,
          info,
        );

        if (!info.isConnectedToInternet) {
          return FF1EnsureReadyResult(
            ff1Device: ff1Device,
            portalIsSet: false,
            isConnectedToInternet: false,
          );
        }

        final topicId = ff1Device.topicId;
        if (topicId.isNotEmpty) {
          params.assertShouldContinue();
          await ref
              .read(ff1WifiControlProvider)
              .showPairingQRCode(topicId: topicId, show: false);
          _throwIfRefUnmounted(ref);
          params.assertShouldContinue();

          return FF1EnsureReadyResult(
            ff1Device: ff1Device,
            portalIsSet: true,
            isConnectedToInternet: true,
          );
        }

        params.assertShouldContinue();
        final topicIdFromKeepWifi = await ref
            .read(ff1ControlProvider)
            .keepWifi(blDevice: params.blDevice);
        _throwIfRefUnmounted(ref);
        params.assertShouldContinue();
        if (topicIdFromKeepWifi.isEmpty) {
          throw Exception('Failed to get topicId from keepWifi');
        }

        ff1Device = ff1Device.copyWith(topicId: topicIdFromKeepWifi);
        return FF1EnsureReadyResult(
          ff1Device: ff1Device,
          portalIsSet: false,
          isConnectedToInternet: true,
        );
      } finally {
        keepAliveLink.close();
      }
    });
