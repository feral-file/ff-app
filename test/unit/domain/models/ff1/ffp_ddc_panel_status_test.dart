import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FfpDdcPanelStatus', () {
    test('fromRelayerPayload parses ffos #84 flat message', () {
      final json = {
        'brightness': 50,
        'contrast': 50,
        'volume': 50,
        'mute': 'off',
        'power': 'on',
        'monitor': 'MSI:MSI MD272UPS',
      };
      final s = FfpDdcPanelStatus.fromRelayerPayload(json);
      expect(s.hasData, isTrue);
      expect(s.brightness, 50);
      expect(s.contrast, 50);
      expect(s.volume, 50);
      expect(s.mute, isFalse);
      expect(s.power, 'on');
      expect(s.monitor, 'MSI:MSI MD272UPS');
    });

    test('errors map hides failed VCP reads in UI terms (field present)', () {
      final json = {
        'monitor': 'X',
        'errors': {'brightness': 'read failed'},
      };
      final s = FfpDdcPanelStatus.fromRelayerPayload(json);
      expect(s.errors?['brightness'], 'read failed');
      expect(s.hasData, isTrue);
    });

    test('nested ddcPanelStatus map', () {
      final json = {
        'ddcPanelStatus': {
          'volume': 10,
          'mute': 'on',
        },
      };
      final s = FfpDdcPanelStatus.fromRelayerPayload(json);
      expect(s.volume, 10);
      expect(s.mute, isTrue);
    });

    test('empty map has no data', () {
      final s = FfpDdcPanelStatus.fromRelayerPayload({});
      expect(s.hasData, isFalse);
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
