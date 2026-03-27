import 'dart:async';

import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/ff1_setup/start_setup_ff1_page.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif_view/gif_view.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

final _log = Logger('FF1DeviceScanPage');

/// Route payload for [FF1DeviceScanPage].
class FF1DeviceScanPagePayload {
  /// Create payload for the FF1 device scan screen.
  FF1DeviceScanPagePayload({
    this.ff1Name,
    this.onFF1Selected,
  });

  /// When null, the scan lists all nearby FF1 devices.
  /// When set, this value is treated as the identity of the target FF1 and
  /// scanning uses name-targeted lookup.
  final String? ff1Name;

  /// When non-null, invoked with the chosen [BluetoothDevice] instead of the
  /// default navigation (pop + push [Routes.startSetupFf1] with
  /// [StartSetupFf1PagePayload]). The caller owns follow-up UX (e.g. navigate
  /// elsewhere). When null, the page logs selection and runs the default route.
  final void Function(BluetoothDevice device)? onFF1Selected;
}

/// FF1 device scan page: discovers nearby FF1 devices over BLE.
class FF1DeviceScanPage extends ConsumerStatefulWidget {
  /// Create the FF1 device scan page.
  const FF1DeviceScanPage({
    required this.payload,
    super.key,
  });

  /// Navigation payload (optional name filter, auto-select, custom selection).
  final FF1DeviceScanPagePayload payload;

  @override
  ConsumerState<FF1DeviceScanPage> createState() => _FF1DeviceScanPageState();
}

class _FF1DeviceScanPageState extends ConsumerState<FF1DeviceScanPage> {
  final _deviceListScrollController = ScrollController();
  double _lastLoggedOffset = 0;

  @override
  void initState() {
    super.initState();
    _deviceListScrollController.addListener(_onDeviceListScrolled);
    final bluetoothState = ref.read(bluetoothAdapterStateProvider);
    final isBluetoothEnabled = bluetoothState.maybeWhen(
      data: (state) => state == BluetoothAdapterState.on,
      orElse: () => false,
    );
    if (isBluetoothEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_startScan(context, trigger: 'initial_load'));
      });
    }
  }

  @override
  void dispose() {
    _deviceListScrollController
      ..removeListener(_onDeviceListScrolled)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref
      // Auto-start scan only once when Bluetooth transitions from off to on
      ..listen<AsyncValue<BluetoothAdapterState>>(
        bluetoothAdapterStateProvider,
        (previous, next) {
          // Only trigger when Bluetooth transitions from off/unknown to on
          final wasEnabled =
              previous?.maybeWhen(
                data: (state) => state == BluetoothAdapterState.on,
                orElse: () => false,
              ) ??
              false;
          final isNowEnabled = next.maybeWhen(
            data: (state) => state == BluetoothAdapterState.on,
            orElse: () => false,
          );

          // Only trigger once when Bluetooth just turned on
          if (!wasEnabled && isNowEnabled) {
            final currentScanState = ref.read(ff1ScanProvider);
            if (!currentScanState.isScanning) {
              AppStructuredLog.logDomainEvent(
                logger: _log,
                event: 'ble_scan_auto_start',
                message: 'Bluetooth enabled, auto-starting scan',
              );
              if (context.mounted) {
                unawaited(_startScan(context, trigger: 'bluetooth_enabled'));
              }
            }
          }
        },
      )
      // Auto-navigate when exactly one matching device is found after scan
      // completes and a name filter was requested.
      ..listen<FF1ScanState>(ff1ScanProvider, (previous, next) {
        final justFinished =
            (previous?.isScanning ?? false) && !next.isScanning;

        final ff1Name = widget.payload.ff1Name;
        final shouldAutoSelect =
            ff1Name != null && justFinished && next.devices.length == 1;

        if (shouldAutoSelect && context.mounted) {
          _onFf1Selected(context, next.devices.first);
        }
      });

    final bluetoothState = ref.watch(bluetoothAdapterStateProvider);
    final scanState = ref.watch(ff1ScanProvider);

    final isBluetoothEnabled = bluetoothState.maybeWhen(
      data: (state) => state == BluetoothAdapterState.on,
      orElse: () => false,
    );

    return Scaffold(
      appBar: const SetupAppBar(
        title: 'Find FF1',
      ),
      backgroundColor: PrimitivesTokens.colorsDarkGrey,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: LayoutConstants.setupPageHorizontal,
          ),
          child: Builder(
            builder: (context) {
              if (!isBluetoothEnabled) {
                return _bluetoothNotAvailableView(context);
              }

              if (scanState.isScanning) {
                return _scanningDevicesView(context);
              }

              if (scanState.error != null && scanState.devices.isEmpty) {
                return _errorView(context, scanState.error);
              }

              if (scanState.devices.isEmpty) {
                return _emptyView(context);
              }

              // Named scan with exactly one match: listener calls [_onFf1Selected];
              // keep a loading-style surface so the picker never flashes.
              final ff1Name = widget.payload.ff1Name;
              if (ff1Name != null &&
                  !scanState.isScanning &&
                  scanState.devices.length == 1 &&
                  scanState.error == null) {
                return _scanningDevicesView(
                  context,
                  isAutoAdvancing: true,
                );
              }

              return _devicePickerView(context, scanState.devices);
            },
          ),
        ),
      ),
    );
  }

  void _onDeviceListScrolled() {
    if (!_deviceListScrollController.hasClients) {
      return;
    }
    final offset = _deviceListScrollController.offset;
    if ((offset - _lastLoggedOffset).abs() < 100) {
      return;
    }
    _lastLoggedOffset = offset;
    AppStructuredLog.forLogger(_log).info(
      category: LogCategory.ui,
      event: 'ui_scroll',
      message: 'scrolled ff1_device_scan_list',
      payload: {
        'target': 'ff1_device_scan_list',
        'offset': offset.toStringAsFixed(1),
      },
    );
  }

  Future<void> _startScan(
    BuildContext context, {
    required String trigger,
  }) async {
    final bluetoothState = ref.read(bluetoothAdapterStateProvider);
    final isBluetoothEnabled = bluetoothState.maybeWhen(
      data: (state) => state == BluetoothAdapterState.on,
      orElse: () => false,
    );

    if (!isBluetoothEnabled) {
      AppStructuredLog.forLogger(_log).warning(
        category: LogCategory.ui,
        event: 'scan_blocked_bluetooth_off',
        message: 'scan blocked because bluetooth is off',
        payload: {
          'bluetoothState': bluetoothState.toString(),
          'trigger': trigger,
        },
      );
      return;
    }

    final ff1Name = widget.payload.ff1Name;

    await AppStructuredLog.runLoggedFlow<void>(
      logger: _log,
      flowName: 'ff1_device_scan',
      payload: {
        'trigger': trigger,
        'ff1Name': ?ff1Name,
      },
      action: () async {
        AppStructuredLog.logUiAction(
          logger: _log,
          action: 'scan_ff1_devices',
          payload: {
            'trigger': trigger,
            'ff1Name': ?ff1Name,
          },
        );
        ref.read(ff1ScanProvider.notifier).clear();
        await ref
            .read(ff1ScanProvider.notifier)
            .startScan(
              timeout: const Duration(seconds: 5),
              ff1Name: ff1Name,
            );
      },
    );
  }

  void _onFf1Selected(
    BuildContext context,
    BluetoothDevice device,
  ) {
    final custom = widget.payload.onFF1Selected;
    if (custom != null) {
      // Pop scan page first to prevent dead-end UX when user cancels from
      // Connect page and returns here.
      context.pop();
      custom(device);
      return;
    }
    AppStructuredLog.logUiAction(
      logger: _log,
      action: 'select_ff1_device',
      entityId: device.remoteId.str,
      payload: {
        'deviceName': device.advName,
      },
    );
    _navigateToStartSetupPage(context, device);
  }

  void _navigateToStartSetupPage(
    BuildContext context,
    BluetoothDevice device,
  ) {
    AppStructuredLog.forLogger(_log).info(
      category: LogCategory.route,
      event: 'navigate_to_start_setup_ff1',
      message: 'navigate to StartSetupFf1Page',
      entityId: device.remoteId.str,
      payload: {'deviceName': device.advName},
    );

    context.pop();
    unawaited(
      context.push(
        Routes.startSetupFf1,
        extra: StartSetupFf1PagePayload(
          selectedDevice: device,
        ),
      ),
    );
  }

  Widget _bluetoothNotAvailableView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error,
          size: LayoutConstants.iconSizeLarge * 2,
          color: AppColor.feralFileLightBlue,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          'Bluetooth is required for setup. Please turn it on to continue.',
          style: AppTypography.h2(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space5),
        PrimaryButton(
          text: 'Open Bluetooth Settings',
          onTap: () async {
            AppStructuredLog.logUiAction(
              logger: _log,
              action: 'open_bluetooth_settings',
            );
            await openAppSettings();
          },
        ),
      ],
    );
  }

  Widget _scanningDevicesView(
    BuildContext context, {
    bool isAutoAdvancing = false,
  }) {
    final ff1Name = widget.payload.ff1Name;
    final String headline;
    if (isAutoAdvancing) {
      headline = ff1Name != null
          ? 'Found $ff1Name. Continuing setup…'
          : 'Continuing setup…';
    } else if (ff1Name != null) {
      headline = 'Searching for $ff1Name...';
    } else {
      headline = 'Searching for nearby FF1 devices...';
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GifView.asset(
          'assets/images/loading.gif',
          width: 139,
          height: 92.67,
          frameRate: 12,
        ),
        const SizedBox(height: 85),
        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: AppTypography.h2(context).white,
              ),
              SizedBox(height: LayoutConstants.space5),
              Text(
                'Keep your phone near FF1 and remain on this screen',
                style: AppTypography.body(context).white,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _errorView(
    BuildContext context,
    Object? error,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error,
          size: LayoutConstants.iconSizeLarge * 2,
          color: AppColor.feralFileLightBlue,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          'Could not find FF1',
          style: AppTypography.h2(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          error != null
              ? 'We could not scan for FF1. '
                    'Check Bluetooth is on, then try again.'
              : 'Please make sure FF1 is powered on and nearby',
          style: AppTypography.body(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space5),
        PrimaryButton(
          text: 'Try again',
          onTap: () => unawaited(
            _startScan(context, trigger: 'error_retry_button'),
          ),
          color: PrimitivesTokens.colorsLightBlue,
          textColor: PrimitivesTokens.colorsBlack,
        ),
        SizedBox(height: LayoutConstants.space4),
      ],
    );
  }

  Widget _emptyView(BuildContext context) {
    final ff1Name = widget.payload.ff1Name;
    final subtitle = ff1Name != null
        ? 'No device named "$ff1Name" was found. '
              'Make sure FF1 is powered on and nearby, then try again'
        : 'Make sure FF1 is powered on and nearby, then try again';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.bluetooth_searching,
          size: LayoutConstants.iconSizeLarge * 2,
          color: PrimitivesTokens.colorsLightBlue,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          'No FF1 devices found',
          style: AppTypography.h2(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          subtitle,
          style: AppTypography.body(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space5),
        PrimaryButton(
          text: 'Try again',
          onTap: () => unawaited(
            _startScan(context, trigger: 'empty_retry_button'),
          ),
          color: PrimitivesTokens.colorsLightBlue,
          textColor: PrimitivesTokens.colorsBlack,
        ),
        SizedBox(height: LayoutConstants.space4),
      ],
    );
  }

  Widget _devicePickerView(
    BuildContext context,
    List<BluetoothDevice> devices,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: LayoutConstants.space16),
        Text(
          'Select the FF1 you want to set up',
          style: AppTypography.body(context).white,
        ),
        SizedBox(height: LayoutConstants.space5),
        Expanded(
          child: ListView.builder(
            controller: _deviceListScrollController,
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];

              return Column(
                children: [
                  _DeviceItem(
                    device: device,
                    onTap: () {
                      _onFf1Selected(context, device);
                    },
                  ),
                  if (index != devices.length - 1)
                    SizedBox(height: LayoutConstants.space3),
                ],
              );
            },
          ),
        ),
        SizedBox(height: LayoutConstants.space4),
        Center(
          child: TextButton(
            onPressed: () => unawaited(
              _startScan(context, trigger: 'scan_again_link'),
            ),
            child: Text(
              "Don't see your device? Scan again",
              style: AppTypography.body(context).white.underline,
            ),
          ),
        ),
        SizedBox(height: LayoutConstants.space4),
      ],
    );
  }
}

class _DeviceItem extends StatelessWidget {
  const _DeviceItem({
    required this.device,
    required this.onTap,
  });

  final BluetoothDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = device.advName.isNotEmpty ? device.advName : 'FF1';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(LayoutConstants.space3),
        decoration: BoxDecoration(
          color: PrimitivesTokens.colorsDarkGrey,
          border: Border.all(
            color: PrimitivesTokens.colorsGrey,
          ),
          borderRadius: BorderRadius.circular(LayoutConstants.space3),
        ),
        child: Row(
          children: [
            Icon(
              Icons.bluetooth,
              color: PrimitivesTokens.colorsGrey,
              size: LayoutConstants.iconSizeMedium,
            ),
            SizedBox(width: LayoutConstants.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.body(context).white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
