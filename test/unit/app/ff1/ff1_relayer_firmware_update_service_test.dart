import 'package:app/app/ff1/ff1_relayer_firmware_update_service.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_test/flutter_test.dart';

import '../providers/provider_test_helpers.dart';

class _StubWifiControl extends FakeWifiControl {
  _StubWifiControl({
    required this.response,
    this.throwOnUpdate = false,
  });

  final FF1CommandResponse response;
  final bool throwOnUpdate;

  @override
  Future<FF1CommandResponse> updateToLatestVersion({
    required String topicId,
  }) async {
    if (throwOnUpdate) {
      throw Exception('network');
    }
    return response;
  }
}

void main() {
  group('Ff1RelayerFirmwareUpdateService', () {
    test('missingTopic when topicId empty', () async {
      final svc = Ff1RelayerFirmwareUpdateService(_StubWifiControl(
        response: FF1CommandResponse(status: 'ok'),
      ));
      expect(
        await svc.start(topicId: ''),
        Ff1RelayerFirmwareUpdateOutcome.missingTopic,
      );
    });

    test('success when response ok', () async {
      final svc = Ff1RelayerFirmwareUpdateService(_StubWifiControl(
        response: FF1CommandResponse(status: 'ok'),
      ));
      expect(
        await svc.start(topicId: 't1'),
        Ff1RelayerFirmwareUpdateOutcome.success,
      );
    });

    test('success when ok flag in data', () async {
      final svc = Ff1RelayerFirmwareUpdateService(_StubWifiControl(
        response: FF1CommandResponse(
          data: <String, dynamic>{'ok': true},
        ),
      ));
      expect(
        await svc.start(topicId: 't1'),
        Ff1RelayerFirmwareUpdateOutcome.success,
      );
    });

    test('relayerRejected when not ok', () async {
      final svc = Ff1RelayerFirmwareUpdateService(_StubWifiControl(
        response: FF1CommandResponse(status: 'error'),
      ));
      expect(
        await svc.start(topicId: 't1'),
        Ff1RelayerFirmwareUpdateOutcome.relayerRejected,
      );
    });

    test('commandFailed on exception', () async {
      final svc = Ff1RelayerFirmwareUpdateService(_StubWifiControl(
        response: FF1CommandResponse(status: 'ok'),
        throwOnUpdate: true,
      ));
      expect(
        await svc.start(topicId: 't1'),
        Ff1RelayerFirmwareUpdateOutcome.commandFailed,
      );
    });
  });
}
