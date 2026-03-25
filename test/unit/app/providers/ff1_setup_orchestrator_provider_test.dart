import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('orchestrator maps connect success to needsWiFi step', () async {
    const connected = ConnectFF1Connected(
      ff1device: FF1Device(
        name: 'FF1',
        remoteId: '00:11',
        deviceId: 'FF1-1',
        topicId: '',
      ),
      portalIsSet: false,
      isConnectedToInternet: false,
    );

    final container = ProviderContainer.test(
      overrides: [
        connectFF1Provider.overrideWith(() => _FakeConnectNotifier(connected)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(connectFF1Provider.future);

    final state = container.read(ff1SetupOrchestratorProvider);
    expect(state.step, FF1SetupStep.needsWiFi);
    expect(state.connected, connected);
  });

  test('orchestrator maps WiFi success to readyForConfig', () async {
    final container = ProviderContainer.test(
      overrides: [
        connectWiFiProvider.overrideWith(() => _FakeWiFiNotifier()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(connectWiFiProvider.notifier) as _FakeWiFiNotifier;
    notifier.emitSuccess(topicId: 'topic-1');

    final state = container.read(ff1SetupOrchestratorProvider);
    expect(state.step, FF1SetupStep.readyForConfig);
    expect(state.wifiState?.status, WiFiConnectionStatus.success);
  });
}

class _FakeConnectNotifier extends ConnectFF1Notifier {
  _FakeConnectNotifier(this._state);

  final ConnectFF1State _state;

  @override
  Future<ConnectFF1State> build() async => _state;
}

class _FakeWiFiNotifier extends WiFiConnectionNotifier {
  void emitSuccess({required String topicId}) {
    state = state.copyWith(status: WiFiConnectionStatus.success, topicId: topicId);
  }
}

