import 'package:app/infra/ff1/wifi_transport/ff1_relayer_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dispose awaits disconnect before closing connection state stream',
    () async {
      FF1RelayerTransport(
        relayerUrl: 'wss://example.invalid/relayer',
      ).dispose();
      // disconnect() delays before connection-state emit; concurrent
      // controller.close() used to race that emit (controller already closed).
      await Future<void>.delayed(const Duration(milliseconds: 150));
    },
  );
}
