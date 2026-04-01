import 'package:app/app/ff1/ff1_firmware_update_prompt_orchestrator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeFirmwareUpdatePromptTick', () {
    const baseSession = Ff1FirmwarePromptSessionState();

    test('resets session when active device id is null', () {
      const session = Ff1FirmwarePromptSessionState(
        lastDeviceId: 'd1',
        sessionPromptedForLatestVersion: '2.0.0',
        isPromptInFlight: true,
      );
      final out = computeFirmwareUpdatePromptTick(
        session: session,
        activeDeviceId: null,
        isInSetupProcess: false,
        isRelayerConnected: true,
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
        dismissedLatestVersionForDevice: '',
      );
      expect(out.session, baseSession);
      expect(out.show, isNull);
    });

    test('resets session fields when device id changes', () {
      const session = Ff1FirmwarePromptSessionState(
        lastDeviceId: 'd1',
        sessionPromptedForLatestVersion: '2.0.0',
      );
      final out = computeFirmwareUpdatePromptTick(
        session: session,
        activeDeviceId: 'd2',
        isInSetupProcess: false,
        isRelayerConnected: true,
        installedVersion: '1.0.0',
        latestVersion: '3.0.0',
        dismissedLatestVersionForDevice: '',
      );
      expect(out.session.lastDeviceId, 'd2');
      expect(out.session.sessionPromptedForLatestVersion, '3.0.0');
      expect(out.session.isPromptInFlight, isTrue);
      expect(out.show?.latestVersion, '3.0.0');
    });

    test('no show when not relayer-connected', () {
      final out = computeFirmwareUpdatePromptTick(
        session: baseSession,
        activeDeviceId: 'd1',
        isInSetupProcess: false,
        isRelayerConnected: false,
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
        dismissedLatestVersionForDevice: '',
      );
      expect(out.show, isNull);
      expect(out.session.lastDeviceId, 'd1');
    });

    test('shows when relayer becomes connected with same version data', () {
      final offline = computeFirmwareUpdatePromptTick(
        session: baseSession,
        activeDeviceId: 'd1',
        isInSetupProcess: false,
        isRelayerConnected: false,
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
        dismissedLatestVersionForDevice: '',
      );
      expect(offline.show, isNull);

      final online = computeFirmwareUpdatePromptTick(
        session: offline.session,
        activeDeviceId: 'd1',
        isInSetupProcess: false,
        isRelayerConnected: true,
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
        dismissedLatestVersionForDevice: '',
      );
      expect(online.show, isNotNull);
      expect(online.show!.latestVersion, '2.0.0');
    });

    test('shows once when eligible then blocks while in flight', () {
      final first = computeFirmwareUpdatePromptTick(
        session: baseSession,
        activeDeviceId: 'd1',
        isInSetupProcess: false,
        isRelayerConnected: true,
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
        dismissedLatestVersionForDevice: '',
      );
      expect(first.show, isNotNull);
      expect(first.session.isPromptInFlight, isTrue);

      final second = computeFirmwareUpdatePromptTick(
        session: first.session,
        activeDeviceId: 'd1',
        isInSetupProcess: false,
        isRelayerConnected: true,
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
        dismissedLatestVersionForDevice: '',
      );
      expect(second.show, isNull);
      expect(second.session, first.session);
    });

    test('after clearInFlight same latest does not show again', () {
      final first = computeFirmwareUpdatePromptTick(
        session: baseSession,
        activeDeviceId: 'd1',
        isInSetupProcess: false,
        isRelayerConnected: true,
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
        dismissedLatestVersionForDevice: '',
      );
      final cleared = clearFirmwareUpdatePromptInFlight(first.session);
      final again = computeFirmwareUpdatePromptTick(
        session: cleared,
        activeDeviceId: 'd1',
        isInSetupProcess: false,
        isRelayerConnected: true,
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
        dismissedLatestVersionForDevice: '',
      );
      expect(again.show, isNull);
    });

    test('after clearInFlight newer latest shows again', () {
      final first = computeFirmwareUpdatePromptTick(
        session: baseSession,
        activeDeviceId: 'd1',
        isInSetupProcess: false,
        isRelayerConnected: true,
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
        dismissedLatestVersionForDevice: '',
      );
      final cleared = clearFirmwareUpdatePromptInFlight(first.session);
      final next = computeFirmwareUpdatePromptTick(
        session: cleared,
        activeDeviceId: 'd1',
        isInSetupProcess: false,
        isRelayerConnected: true,
        installedVersion: '1.0.0',
        latestVersion: '2.1.0',
        dismissedLatestVersionForDevice: '',
      );
      expect(next.show?.latestVersion, '2.1.0');
      expect(next.session.sessionPromptedForLatestVersion, '2.1.0');
    });

    test('no show when user dismissed this latest', () {
      final out = computeFirmwareUpdatePromptTick(
        session: baseSession,
        activeDeviceId: 'd1',
        isInSetupProcess: false,
        isRelayerConnected: true,
        installedVersion: '1.0.0',
        latestVersion: '2.0.0',
        dismissedLatestVersionForDevice: '2.0.0',
      );
      expect(out.show, isNull);
    });
  });
}
