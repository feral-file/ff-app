import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FfpDdcPanelStatus', () {
    test('fromJson parses ffos #84 flat message', () {
      final json = {
        'brightness': 50,
        'contrast': 50,
        'volume': 50,
        'mute': 'off',
        'power': 'on',
        'monitor': 'MSI:MSI MD272UPS',
      };
      final s = FfpDdcPanelStatus.fromJson(json);
      expect(s.hasData, isTrue);
      expect(s.brightness, 50);
      expect(s.contrast, 50);
      expect(s.volume, 50);
      expect(s.mute, isFalse);
      expect(s.power, FfpDdcPanelPower.on);
      expect(s.monitor, 'MSI:MSI MD272UPS');
    });

    test('monitor-only payload has data', () {
      final json = {
        'monitor': 'X',
      };
      final s = FfpDdcPanelStatus.fromJson(json);
      expect(s.hasData, isTrue);
    });

    test('volume-only payload does not count as displayable status', () {
      final json = {
        'volume': 77,
      };
      final s = FfpDdcPanelStatus.fromJson(json);
      expect(s.volume, 77);
      expect(s.hasData, isFalse);
    });

    test(
      'relayer sample with only errors in JSON still parses null values',
      () {
      final json = {
        'brightness': 82,
        'contrast': 25,
        'volume': 77,
        'power': 'on',
        'monitor': 'DEL:DELL S2721QS',
        'errors': {'mute': 'VCP reported ERR'},
      };
      final s = FfpDdcPanelStatus.fromJson(json);
      expect(s.brightness, 82);
      expect(s.contrast, 25);
      expect(s.volume, 77);
      expect(s.power, FfpDdcPanelPower.on);
      expect(s.monitor, 'DEL:DELL S2721QS');
      expect(s.mute, isNull);
      expect(s.hasData, isTrue);
      },
    );

    test('FfpDdcPanelPower.tryParse accepts wire aliases', () {
      expect(FfpDdcPanelPower.tryParse('poweron'), FfpDdcPanelPower.on);
      expect(FfpDdcPanelPower.tryParse('POWEROFF'), FfpDdcPanelPower.off);
      expect(FfpDdcPanelPower.tryParse('suspend'), FfpDdcPanelPower.standby);
      expect(FfpDdcPanelPower.tryParse('unknown'), isNull);
    });

    test('empty map has no data', () {
      final s = FfpDdcPanelStatus.fromJson({});
      expect(s.hasData, isFalse);
    });

    test('toJson roundtrips parsed fields', () {
      final s = FfpDdcPanelStatus.fromJson({
        'brightness': 10,
        'mute': 'on',
        'power': 'standby',
        'monitor': 'X',
      });
      final s2 = FfpDdcPanelStatus.fromJson(s.toJson());
      expect(s2.brightness, s.brightness);
      expect(s2.mute, s.mute);
      expect(s2.power, s.power);
      expect(s2.monitor, s.monitor);
    });

    test('copyWith updates one field and keeps the rest', () {
      const base = FfpDdcPanelStatus(
        brightness: 40,
        contrast: 50,
        monitor: 'X',
      );
      final u = base.copyWith(brightness: 80);
      expect(u.brightness, 80);
      expect(u.contrast, 50);
      expect(u.monitor, 'X');
    });
  });
}
