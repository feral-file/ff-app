import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FfpDdcPanelStatus', () {
    test('fromJson parses panels list', () {
      final json = {
        'panels': [
          {
            'monitorId': 'm1',
            'displayName': 'HDMI-1',
            'powerState': 'on',
            'brightness': 40,
            'contrast': 50,
            'monitorVolume': 60,
            'isMuted': false,
            'capabilities': {
              'brightness': false,
              'contrast': true,
              'volume': true,
              'mute': true,
            },
          },
        ],
      };
      final s = FfpDdcPanelStatus.fromJson(json);
      expect(s.panels, hasLength(1));
      final p = s.panels.single;
      expect(p.monitorId, 'm1');
      expect(p.displayName, 'HDMI-1');
      expect(p.powerState, FfpDdcPowerState.on);
      expect(p.brightnessPercent, 40);
      expect(p.contrastPercent, 50);
      expect(p.monitorVolumePercent, 60);
      expect(p.isMuted, isFalse);
      expect(p.capabilities.brightnessSupported, isFalse);
      expect(p.capabilities.contrastSupported, isTrue);
    });

    test('fromRelayerPayload unwraps ddcPanelStatus', () {
      final json = {
        'ddcPanelStatus': {
          'panels': [
            {'monitorId': 'a', 'powerState': 'standby'},
          ],
        },
      };
      final s = FfpDdcPanelStatus.fromRelayerPayload(json);
      expect(s.panels.single.powerState, FfpDdcPowerState.standby);
    });

    test('empty panels when missing', () {
      final s = FfpDdcPanelStatus.fromJson({});
      expect(s.panels, isEmpty);
    });
  });
}
