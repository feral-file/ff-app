import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wire shape from ffos issue 84 comment (`ddcPanelControl` + action/value).
void main() {
  group('FfpDdc panel control wire (ffos#84)', () {
    test('brightness uses ddcPanelControl + numeric value', () {
      const r = FfpDdcMonitorSetBrightnessRequest(
        monitorId: 'MSI:MSI MD272UPS',
        percent: 42,
      );
      expect(r.command, 'ddcPanelControl');
      expect(r.params, {'action': 'brightness', 'value': 42});
    });

    test('mute uses string on/off', () {
      const r = FfpDdcMonitorSetMuteRequest(
        monitorId: 'x',
        muted: false,
      );
      expect(r.command, 'ddcPanelControl');
      expect(r.params, {'action': 'mute', 'value': 'off'});
    });

    test('power passes wire string', () {
      const r = FfpDdcMonitorSetPowerRequest(
        monitorId: 'x',
        powerState: 'standby',
      );
      expect(r.command, 'ddcPanelControl');
      expect(r.params, {'action': 'power', 'value': 'standby'});
    });
  });
}
