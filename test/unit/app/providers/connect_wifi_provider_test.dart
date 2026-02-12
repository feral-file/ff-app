import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('connectWiFiProvider supports select and reset', () {
    // Unit test: verifies WiFi connection notifier local state updates for select/reset.
    final container = ProviderContainer.test();
    addTearDown(container.dispose);
    final notifier = container.read(connectWiFiProvider.notifier);

    notifier.selectNetwork(const WiFiNetwork('Office'));
    expect(container.read(connectWiFiProvider).selectedNetwork?.ssid, 'Office');

    notifier.reset();
    expect(container.read(connectWiFiProvider).selectedNetwork, isNull);
    expect(
      container.read(connectWiFiProvider).status,
      WiFiConnectionStatus.idle,
    );
  });
}
