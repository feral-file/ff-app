import 'dart:async';

import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/ui/screens/ff1_setup/ff1_device_scan_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final deviceA = BluetoothDevice.fromId('00:11:22:33:44:55');
  final deviceB = BluetoothDevice.fromId('AA:BB:CC:DD:EE:FF');

  testWidgets(
    'without ff1Name and one device, shows picker (no auto-advance)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bluetoothAdapterStateProvider.overrideWith(
              (ref) => Stream.value(BluetoothAdapterState.on),
            ),
            ff1ScanProvider.overrideWith(
              () => _ScriptedFf1ScanNotifier(
                ({ff1Name}) async => [deviceA],
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: Routes.ff1DeviceScanPage,
              routes: [
                GoRoute(
                  path: Routes.ff1DeviceScanPage,
                  builder: (context, state) =>
                      FF1DeviceScanPage(payload: FF1DeviceScanPagePayload()),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Select the FF1 you want to set up'), findsOneWidget);
      expect(find.textContaining('Continuing setup'), findsNothing);
    },
  );

  testWidgets(
    'with ff1Name and one device, auto-selects to start setup route',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bluetoothAdapterStateProvider.overrideWith(
              (ref) => Stream.value(BluetoothAdapterState.on),
            ),
            ff1ScanProvider.overrideWith(
              () => _ScriptedFf1ScanNotifier(
                ({ff1Name}) async => [deviceA],
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/entry',
              routes: [
                GoRoute(
                  path: '/entry',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => unawaited(
                          context.push(
                            Routes.ff1DeviceScanPage,
                            extra: FF1DeviceScanPagePayload(
                              ff1Name: 'MyFf1',
                            ),
                          ),
                        ),
                        child: const Text('Open scan'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.ff1DeviceScanPage,
                  builder: (context, state) {
                    final extra = state.extra;
                    final resolved = extra is FF1DeviceScanPagePayload
                        ? extra
                        : FF1DeviceScanPagePayload();
                    return FF1DeviceScanPage(payload: resolved);
                  },
                ),
                GoRoute(
                  path: Routes.startSetupFf1,
                  builder: (context, state) => const Scaffold(
                    body: Text('START_SETUP_FF1_TEST_MARKER'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open scan'));
      await tester.pumpAndSettle();

      expect(find.text('START_SETUP_FF1_TEST_MARKER'), findsOneWidget);
    },
  );

  testWidgets(
    'with ff1Name and two devices, shows picker',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bluetoothAdapterStateProvider.overrideWith(
              (ref) => Stream.value(BluetoothAdapterState.on),
            ),
            ff1ScanProvider.overrideWith(
              () => _ScriptedFf1ScanNotifier(
                ({ff1Name}) async => [deviceA, deviceB],
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: Routes.ff1DeviceScanPage,
              routes: [
                GoRoute(
                  path: Routes.ff1DeviceScanPage,
                  builder: (context, state) =>
                      FF1DeviceScanPage(
                    payload: FF1DeviceScanPagePayload(ff1Name: 'MyFf1'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Select the FF1 you want to set up'), findsOneWidget);
      expect(find.textContaining('Continuing setup'), findsNothing);
    },
  );

  testWidgets(
    'custom callback pops scan page before invoking',
    (tester) async {
      BluetoothDevice? selectedDevice;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bluetoothAdapterStateProvider.overrideWith(
              (ref) => Stream.value(BluetoothAdapterState.on),
            ),
            ff1ScanProvider.overrideWith(
              () => _ScriptedFf1ScanNotifier(
                ({ff1Name}) async => [deviceA],
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/entry',
              routes: [
                GoRoute(
                  path: '/entry',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => unawaited(
                          context.push(
                            Routes.ff1DeviceScanPage,
                            extra: FF1DeviceScanPagePayload(
                              ff1Name: 'MyFf1',
                              onFF1Selected: (device) {
                                selectedDevice = device;
                              },
                            ),
                          ),
                        ),
                        child: const Text('Open scan'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.ff1DeviceScanPage,
                  builder: (context, state) {
                    final extra = state.extra;
                    final resolved = extra is FF1DeviceScanPagePayload
                        ? extra
                        : FF1DeviceScanPagePayload();
                    return FF1DeviceScanPage(payload: resolved);
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open scan'));
      await tester.pumpAndSettle();

      // Scan page should be popped and we're back at entry
      expect(find.text('Open scan'), findsOneWidget);
      expect(find.text('Select the FF1 you want to set up'), findsNothing);
      expect(selectedDevice, equals(deviceA));
    },
  );

}

/// Test double: drives scan results without BLE.
/// Mirrors [FF1ScanNotifier.startScan] control flow.
class _ScriptedFf1ScanNotifier extends FF1ScanNotifier {
  _ScriptedFf1ScanNotifier(this._onScan);

  final Future<List<BluetoothDevice>> Function({String? ff1Name}) _onScan;

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 30),
    String? ff1Name,
  }) async {
    if (state.isScanning) {
      return;
    }
    state = state.copyWith(isScanning: true);
    try {
      final devices = await _onScan(ff1Name: ff1Name);
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(isScanning: false, devices: devices);
    } on Object catch (e) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(isScanning: false, error: e);
    }
  }
}
