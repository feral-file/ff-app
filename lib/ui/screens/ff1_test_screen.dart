import 'dart:async';

import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

///
/// This screen demonstrates the FF1 Bluetooth integration:
/// 1. Scan for FF1 devices in range
/// 2. Connect to a selected device
/// 3. Send WiFi credentials and log the response
class FF1TestScreen extends ConsumerStatefulWidget {
  const FF1TestScreen({super.key});

  @override
  ConsumerState<FF1TestScreen> createState() => _FF1TestScreenState();
}

class _FF1TestScreenState extends ConsumerState<FF1TestScreen> {
  final _log = Logger('FF1TestScreen');
  final _ssidController = TextEditingController(text: 'TestNetwork');
  final _passwordController = TextEditingController(text: 'password123');

  BluetoothDevice? _selectedDevice;
  bool _isConnecting = false;
  String? _connectionError;
  String? _wifiResult;
  String? _topicId;
  bool _showQrCode = true;
  bool _isTestingConnection = false;
  String? _connectionTestResult;

  @override
  void initState() {
    super.initState();
    unawaited(_requestBluetoothPermission());
  }

  Future<void> _requestBluetoothPermission() async {
    try {
      // Request Bluetooth permissions for Android 12+
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();

      // Also request legacy Bluetooth for older Android versions
      final bluetoothStatus = await Permission.bluetooth.request();
      PermissionStatus? locationStatus;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final sdkInt = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        if (sdkInt <= 30) {
          locationStatus = await Permission.locationWhenInUse.request();
        }
      }

      _log.info(
        'Bluetooth permissions - Scan: $scanStatus, Connect: $connectStatus, '
        'Legacy: $bluetoothStatus, Location: $locationStatus',
      );

      // If any permission is permanently denied, offer to open app settings
      if (scanStatus.isDenied ||
          connectStatus.isDenied ||
          bluetoothStatus.isDenied ||
          (locationStatus?.isDenied ?? false)) {
        _log.warning(
          'Bluetooth permissions denied. Offering to open app settings.',
        );
        _offerOpenAppSettings();
      } else if (scanStatus.isPermanentlyDenied ||
          connectStatus.isPermanentlyDenied ||
          bluetoothStatus.isPermanentlyDenied ||
          (locationStatus?.isPermanentlyDenied ?? false)) {
        _log.warning(
          'Bluetooth permissions permanently denied. Must open app settings.',
        );
        _offerOpenAppSettings();
      }
    } catch (e) {
      _log.severe('Failed to request Bluetooth permissions: $e');
    }
  }

  Future<void> _offerOpenAppSettings() async {
    if (!mounted) return;

    final shouldOpen = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bluetooth Permission Required'),
            content: const Text(
              'This app needs Bluetooth permission to scan and connect to FF1 devices. '
              'Please enable it in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldOpen) {
      openAppSettings();
    }
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connectToDevice(BluetoothDevice blDevice) async {
    setState(() {
      _isConnecting = true;
      _connectionError = null;
      _wifiResult = null;
    });

    try {
      final control = ref.read(ff1ControlProvider);

      _log.info('Connecting to ${blDevice.advName}...');

      await control.connect(blDevice: blDevice);

      _log.info('Connected! Getting device info...');

      // Get device info
      final info = await control.getInfo(blDevice: blDevice);
      _log.info('Device info: $info');

      setState(() {
        _selectedDevice = blDevice;
        _isConnecting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${blDevice.advName}')),
        );
      }
    } catch (e) {
      _log.severe('Connection failed: $e');
      setState(() {
        _connectionError = e.toString();
        _isConnecting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    }
  }

  Future<void> _sendWifiCredentials() async {
    if (_selectedDevice == null) return;

    setState(() {
      _wifiResult = 'Sending WiFi credentials...';
    });

    try {
      final control = ref.read(ff1ControlProvider);

      final ssid = _ssidController.text;
      final password = _passwordController.text;

      // Set device timezone first (required before WiFi setup)
      try {
        _log.info('Setting device timezone...');
        setState(() {
          _wifiResult = 'Setting device timezone...';
        });

        // Get system timezone
        final now = DateTime.now();
        final timezone = now.timeZoneName;

        await control.setTimezone(
          blDevice: _selectedDevice!,
          timezone: timezone,
          time: now,
        );

        _log.info('Timezone set successfully: $timezone');
      } catch (e) {
        _log.warning('Failed to set timezone (continuing anyway): $e');
        // Continue even if timezone fails
      }

      _log.info('Sending WiFi credentials: SSID=$ssid');
      setState(() {
        _wifiResult = 'Sending WiFi credentials...';
      });

      final topicId = await control.sendWifiCredentials(
        blDevice: _selectedDevice!,
        ssid: ssid,
        password: password,
      );

      _log.info('SUCCESS! Topic ID: $topicId');

      // Hide QR code and keep WiFi connection
      setState(() {
        _topicId = topicId;
        _showQrCode = false;
        _wifiResult = 'WiFi credentials sent!\n\nHiding QR code...';
      });

      // Call keepWifi to confirm connection
      _log.info('Confirming WiFi connection...');
      await control.keepWifi(blDevice: _selectedDevice!);

      setState(() {
        _wifiResult = 'SUCCESS!\n\nTopic ID: $topicId\n\n'
            'The device is now connected to WiFi and can be controlled '
            'via cloud WebSocket.\n\n'
            'Tap "Test WiFi Connection" to verify connectivity.';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WiFi credentials sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _log.severe('Failed to send WiFi credentials: $e');

      setState(() {
        _wifiResult = 'FAILED!\n\nError: $e';
        _showQrCode = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scanWifi() async {
    if (_selectedDevice == null) return;

    try {
      final control = ref.read(ff1ControlProvider);

      _log.info('Scanning for WiFi networks...');

      final ssids = await control.scanWifi(blDevice: _selectedDevice!);

      _log.info('Found ${ssids.length} networks: $ssids');

      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Available Networks'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: ssids.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.wifi),
                    title: Text(ssids[index]),
                    onTap: () {
                      _ssidController.text = ssids[index];
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _log.severe('WiFi scan failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('WiFi scan failed: $e')),
        );
      }
    }
  }

  /// Test WiFi connection by rotating the device 4 times
  Future<void> _testWifiConnection() async {
    if (_topicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Send WiFi credentials first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionTestResult = 'Testing WiFi connection with rotation...\n\n';
    });

    try {
      final wifiControl = ref.read(ff1WifiControlProvider);

      _log.info('Testing WiFi connection with topicId: $_topicId');

      // Rotate 4 times to test the connection
      for (var i = 1; i <= 4; i++) {
        try {
          _log.info('Rotation $i/4 - Sending rotate command...');

          // Send rotate command via WiFi
          final response = await wifiControl.rotate(
            topicId: _topicId!,
            angle: 90,
          );

          _log.info('Rotation $i/4 - Response: ${response.status}');

          setState(() {
            _connectionTestResult =
                '${_connectionTestResult!}Rotation $i/4 - OK '
                '(status: ${response.status})\n';
          });

          // Delay between rotations
          await Future<void>.delayed(const Duration(seconds: 2));
        } catch (e) {
          _log.warning('Rotation $i/4 failed: $e');
          setState(() {
            _connectionTestResult =
                '${_connectionTestResult!}Rotation $i/4 - FAILED: $e\n';
          });
        }
      }

      setState(() {
        _connectionTestResult =
            '${_connectionTestResult!}\n✓ All 4 rotations completed successfully!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('WiFi connection test passed!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _log.severe('WiFi connection test failed: $e');

      setState(() {
        _connectionTestResult = 'Connection test FAILED!\n\nError: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  /// Send a rotate command to the device
  Future<void> _rotateDevice() async {
    if (_topicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Send WiFi credentials first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final wifiControl = ref.read(ff1WifiControlProvider);
      _log.info('Sending rotate command...');

      final response = await wifiControl.rotate(
        topicId: _topicId!,
        angle: 90,
      );

      _log.info('Rotate command successful: ${response.status}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rotate command sent! Status: ${response.status}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _log.severe('Rotate command failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rotate failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send a pause command to the device
  Future<void> _pauseDevice() async {
    if (_topicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Send WiFi credentials first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final wifiControl = ref.read(ff1WifiControlProvider);
      _log.info('Sending pause command...');

      final response = await wifiControl.pause(topicId: _topicId!);

      _log.info('Pause command successful: ${response.status}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pause command sent! Status: ${response.status}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _log.severe('Pause command failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pause failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send a play command to the device
  Future<void> _playDevice() async {
    if (_topicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Send WiFi credentials first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final wifiControl = ref.read(ff1WifiControlProvider);
      _log.info('Sending play command...');

      final response = await wifiControl.play(topicId: _topicId!);

      _log.info('Play command successful: ${response.status}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Play command sent! Status: ${response.status}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _log.severe('Play command failed: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Play failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(ff1ScanProvider);
    final bluetoothState = ref.watch(bluetoothAdapterStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FF1 Bluetooth Test'),
        actions: [
          if (scanState.isScanning)
            Padding(
              padding: EdgeInsets.all(LayoutConstants.space4),
              child: loadingIndicator(
                valueColor: AppColor.white,
                size: LayoutConstants.iconSizeMedium,
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                unawaited(ref.read(ff1ScanProvider.notifier).startScan());
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Bluetooth status
          _buildBluetoothStatus(bluetoothState),

          // Device list
          Expanded(
            child: _selectedDevice == null
                ? _buildDeviceList(scanState)
                : _buildDeviceControl(),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothStatus(AsyncValue<BluetoothAdapterState> state) {
    return state.when(
      data: (adapterState) {
        if (adapterState == BluetoothAdapterState.on) {
          return const SizedBox.shrink();
        }

        return Container(
          color: Colors.orange,
          padding: EdgeInsets.all(LayoutConstants.space4),
          child: Row(
            children: [
              const Icon(Icons.bluetooth_disabled, color: Colors.white),
              SizedBox(width: LayoutConstants.space3),
              Expanded(
                child: Text(
                  'Bluetooth is ${adapterState.name}',
                  style: AppTypography.body(context).white,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (Object _, StackTrace __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDeviceList(FF1ScanState scanState) {
    if (scanState.devices.isEmpty && !scanState.isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_searching,
              size: LayoutConstants.space16,
              color: AppColor.auQuickSilver,
            ),
            SizedBox(height: LayoutConstants.space4),
            Text(
              'No FF1 devices found',
              style: AppTypography.body(context).grey,
            ),
            SizedBox(height: LayoutConstants.space6),
            ElevatedButton.icon(
              onPressed: () {
                unawaited(ref.read(ff1ScanProvider.notifier).startScan());
              },
              icon: const Icon(Icons.search),
              label: Text(
                'Start scan',
                style: AppTypography.body(context).white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: scanState.devices.length,
      itemBuilder: (context, index) {
        final device = scanState.devices[index];
        final name =
            device.advName.isNotEmpty ? device.advName : device.remoteId.str;

        return ListTile(
          leading: const Icon(Icons.devices),
          title: Text(name),
          subtitle: Text(device.remoteId.str),
          trailing: _isConnecting
              ? loadingIndicator(
                  valueColor: AppColor.white,
                  size: LayoutConstants.iconSizeMedium,
                )
              : const Icon(Icons.chevron_right),
          onTap: _isConnecting ? null : () => _connectToDevice(device),
        );
      },
    );
  }

  Widget _buildDeviceControl() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(LayoutConstants.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connected device info
          Card(
            child: Padding(
              padding: EdgeInsets.all(LayoutConstants.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: LayoutConstants.space2),
                      Text(
                        'Connected',
                        style: AppTypography.bodyBold(context),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDevice = null;
                            _wifiResult = null;
                          });
                        },
                        child: Text(
                          'Disconnect',
                          style: AppTypography.body(context),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: LayoutConstants.space2),
                  Text(
                    'Device: ${_selectedDevice!.remoteId.str}',
                    style: AppTypography.body(context),
                  ),
                  Text(
                    'Remote ID: ${_selectedDevice!.remoteId}',
                    style: AppTypography.body(context),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: LayoutConstants.space6),

          // WiFi credentials form
          Text(
            'WiFi Credentials',
            style: AppTypography.h3(context),
          ),
          SizedBox(height: LayoutConstants.space4),

          TextField(
            controller: _ssidController,
            decoration: InputDecoration(
              labelText: 'SSID',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.wifi_find),
                onPressed: _scanWifi,
                tooltip: 'Scan WiFi',
              ),
            ),
          ),
          SizedBox(height: LayoutConstants.space3),

          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          SizedBox(height: LayoutConstants.space4),

          ElevatedButton.icon(
            onPressed: _sendWifiCredentials,
            icon: const Icon(Icons.send),
            label: Text(
              'Send WiFi credentials',
              style: AppTypography.body(context).white,
            ),
          ),

          if (_wifiResult != null && !_showQrCode) ...[
            SizedBox(height: LayoutConstants.space4),
            ElevatedButton.icon(
              onPressed: _isTestingConnection ? null : _testWifiConnection,
              icon: const Icon(Icons.check_circle),
              label: _isTestingConnection
                  ? loadingIndicator(
                      valueColor: AppColor.white,
                      size: LayoutConstants.iconSizeMedium,
                    )
                  : Text(
                      'Test WiFi connection',
                      style: AppTypography.body(context).white,
                    ),
            ),
            SizedBox(height: LayoutConstants.space6),
            Text(
              'WiFi Commands',
              style: AppTypography.h3(context),
            ),
            SizedBox(height: LayoutConstants.space3),
            ElevatedButton.icon(
              onPressed: _topicId != null ? _rotateDevice : null,
              icon: const Icon(Icons.rotate_right),
              label: Text(
                'Rotate 90°',
                style: AppTypography.body(context).white,
              ),
            ),
            SizedBox(height: LayoutConstants.space2),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _topicId != null ? _playDevice : null,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      'Play',
                      style: AppTypography.body(context).white,
                    ),
                  ),
                ),
                SizedBox(width: LayoutConstants.space2),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _topicId != null ? _pauseDevice : null,
                    icon: const Icon(Icons.pause),
                    label: Text(
                      'Pause',
                      style: AppTypography.body(context).white,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_wifiResult != null) ...[
            SizedBox(height: LayoutConstants.space6),
            Card(
              color: _wifiResult!.contains('SUCCESS')
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Padding(
                padding: EdgeInsets.all(LayoutConstants.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Result',
                      style: AppTypography.bodyBold(context).copyWith(
                        color: _wifiResult!.contains('SUCCESS')
                            ? Colors.green.shade900
                            : Colors.red.shade900,
                      ),
                    ),
                    SizedBox(height: LayoutConstants.space2),
                    Text(
                      _wifiResult!,
                      style: AppTypography.body(context).copyWith(
                        color: _wifiResult!.contains('SUCCESS')
                            ? Colors.green.shade900
                            : Colors.red.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_connectionTestResult != null) ...[
            SizedBox(height: LayoutConstants.space4),
            Card(
              color: _connectionTestResult!.contains('successfully')
                  ? Colors.blue.shade50
                  : Colors.orange.shade50,
              child: Padding(
                padding: EdgeInsets.all(LayoutConstants.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Test',
                      style: AppTypography.bodyBold(context).copyWith(
                        color: _connectionTestResult!.contains('successfully')
                            ? Colors.blue.shade900
                            : Colors.orange.shade900,
                      ),
                    ),
                    SizedBox(height: LayoutConstants.space2),
                    Text(
                      _connectionTestResult!,
                      style: AppTypography.monoSmall(context).copyWith(
                        color: _connectionTestResult!.contains('successfully')
                            ? Colors.blue.shade900
                            : Colors.orange.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_connectionError != null) ...[
            SizedBox(height: LayoutConstants.space4),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: EdgeInsets.all(LayoutConstants.space4),
                child: Text(
                  'Connection Error: $_connectionError',
                  style: AppTypography.body(context).copyWith(
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
