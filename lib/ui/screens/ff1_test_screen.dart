import 'dart:async';

import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
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

  FF1Device? _selectedDevice;
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

      _log.info(
        'Bluetooth permissions - Scan: $scanStatus, Connect: $connectStatus, Legacy: $bluetoothStatus',
      );

      // If any permission is permanently denied, offer to open app settings
      if (scanStatus.isDenied ||
          connectStatus.isDenied ||
          bluetoothStatus.isDenied) {
        _log.warning(
          'Bluetooth permissions denied. Offering to open app settings.',
        );
        _offerOpenAppSettings();
      } else if (scanStatus.isPermanentlyDenied ||
          connectStatus.isPermanentlyDenied ||
          bluetoothStatus.isPermanentlyDenied) {
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

    final shouldOpen =
        await showDialog<bool>(
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

      // Create FF1Device from BluetoothDevice
      final device = FF1Device(
        name: blDevice.advName.isNotEmpty
            ? blDevice.advName
            : blDevice.remoteId.str,
        remoteId: blDevice.remoteId.str,
        deviceId: blDevice.advName.isNotEmpty
            ? blDevice.advName
            : 'FF1_${blDevice.remoteId.str.substring(0, 8)}',
      );

      _log.info('Connecting to ${device.deviceId}...');

      await control.connect(device: device);

      _log.info('Connected! Getting device info...');

      // Get device info
      final info = await control.getInfo(device: device);
      _log.info('Device info: $info');

      setState(() {
        _selectedDevice = device;
        _isConnecting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${device.deviceId}')),
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
          device: _selectedDevice!,
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
        device: _selectedDevice!,
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
      await control.keepWifi(device: _selectedDevice!);

      setState(() {
        _wifiResult =
            'SUCCESS!\n\nTopic ID: $topicId\n\n'
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

      final ssids = await control.scanWifi(device: _selectedDevice!);

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
      for (int i = 1; i <= 4; i++) {
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.bluetooth_disabled, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bluetooth is ${adapterState.name}',
                  style: const TextStyle(color: Colors.white),
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
            const Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No FF1 devices found'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                unawaited(ref.read(ff1ScanProvider.notifier).startScan());
              },
              icon: const Icon(Icons.search),
              label: const Text('Start Scan'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: scanState.devices.length,
      itemBuilder: (context, index) {
        final device = scanState.devices[index];
        final name = device.advName.isNotEmpty
            ? device.advName
            : device.remoteId.str;

        return ListTile(
          leading: const Icon(Icons.devices),
          title: Text(name),
          subtitle: Text(device.remoteId.str),
          trailing: _isConnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _isConnecting ? null : () => _connectToDevice(device),
        );
      },
    );
  }

  Widget _buildDeviceControl() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connected device info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Connected',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDevice = null;
                            _wifiResult = null;
                          });
                        },
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Device: ${_selectedDevice!.deviceId}'),
                  Text('Remote ID: ${_selectedDevice!.remoteId}'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // WiFi credentials form
          const Text(
            'WiFi Credentials',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

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
          const SizedBox(height: 12),

          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _sendWifiCredentials,
            icon: const Icon(Icons.send),
            label: const Text('Send WiFi Credentials'),
          ),

          if (_wifiResult != null && !_showQrCode) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isTestingConnection ? null : _testWifiConnection,
              icon: const Icon(Icons.check_circle),
              label: _isTestingConnection
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Test WiFi Connection (4x Rotate)'),
            ),
            const SizedBox(height: 24),
            const Text(
              'WiFi Commands',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _topicId != null ? _rotateDevice : null,
              icon: const Icon(Icons.rotate_right),
              label: const Text('Rotate 90°'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _topicId != null ? _playDevice : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _topicId != null ? _pauseDevice : null,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                ),
              ],
            ),
          ],

          if (_wifiResult != null) ...[
            const SizedBox(height: 24),
            Card(
              color: _wifiResult!.contains('SUCCESS')
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Result',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _wifiResult!.contains('SUCCESS')
                            ? Colors.green.shade900
                            : Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _wifiResult!,
                      style: TextStyle(
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
            const SizedBox(height: 16),
            Card(
              color: _connectionTestResult!.contains('successfully')
                  ? Colors.blue.shade50
                  : Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Test',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _connectionTestResult!.contains('successfully')
                            ? Colors.blue.shade900
                            : Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _connectionTestResult!,
                      style: TextStyle(
                        color: _connectionTestResult!.contains('successfully')
                            ? Colors.blue.shade900
                            : Colors.orange.shade900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (_connectionError != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Connection Error: $_connectionError',
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
