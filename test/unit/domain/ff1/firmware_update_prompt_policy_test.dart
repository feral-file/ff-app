import 'package:app/domain/ff1/firmware_update_prompt_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldOfferFirmwareUpdateAutoPrompt', () {
    test('false during setup', () {
      expect(
        shouldOfferFirmwareUpdateAutoPrompt(
          isInSetupProcess: true,
          isRelayerConnected: true,
          installedVersion: '1.0.0',
          latestVersion: '2.0.0',
          dismissedLatestVersionForDevice: '',
        ),
        isFalse,
      );
    });

    test('false when not relayer-connected', () {
      expect(
        shouldOfferFirmwareUpdateAutoPrompt(
          isInSetupProcess: false,
          isRelayerConnected: false,
          installedVersion: '1.0.0',
          latestVersion: '2.0.0',
          dismissedLatestVersionForDevice: '',
        ),
        isFalse,
      );
    });

    test('false when missing version fields', () {
      expect(
        shouldOfferFirmwareUpdateAutoPrompt(
          isInSetupProcess: false,
          isRelayerConnected: true,
          installedVersion: null,
          latestVersion: '2.0.0',
          dismissedLatestVersionForDevice: '',
        ),
        isFalse,
      );
      expect(
        shouldOfferFirmwareUpdateAutoPrompt(
          isInSetupProcess: false,
          isRelayerConnected: true,
          installedVersion: '1.0.0',
          latestVersion: null,
          dismissedLatestVersionForDevice: '',
        ),
        isFalse,
      );
    });

    test('false when already on latest', () {
      expect(
        shouldOfferFirmwareUpdateAutoPrompt(
          isInSetupProcess: false,
          isRelayerConnected: true,
          installedVersion: '2.0.0',
          latestVersion: '2.0.0',
          dismissedLatestVersionForDevice: '',
        ),
        isFalse,
      );
    });

    test('false when user dismissed this latest version', () {
      expect(
        shouldOfferFirmwareUpdateAutoPrompt(
          isInSetupProcess: false,
          isRelayerConnected: true,
          installedVersion: '1.0.0',
          latestVersion: '2.0.0',
          dismissedLatestVersionForDevice: '2.0.0',
        ),
        isFalse,
      );
    });

    test('true when update available, connected, post-setup, not dismissed', () {
      expect(
        shouldOfferFirmwareUpdateAutoPrompt(
          isInSetupProcess: false,
          isRelayerConnected: true,
          installedVersion: '1.0.0',
          latestVersion: '2.0.0',
          dismissedLatestVersionForDevice: '',
        ),
        isTrue,
      );
    });

    test('true when dismissed older version but latest moved forward', () {
      expect(
        shouldOfferFirmwareUpdateAutoPrompt(
          isInSetupProcess: false,
          isRelayerConnected: true,
          installedVersion: '1.0.0',
          latestVersion: '2.1.0',
          dismissedLatestVersionForDevice: '2.0.0',
        ),
        isTrue,
      );
    });
  });
}
