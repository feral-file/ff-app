import 'package:app/app/providers/ff1_connection_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Screen for entering WiFi password (Step 4 of the flow)
/// 
/// User selects a network and enters password here
class EnterWiFiPasswordScreen extends ConsumerStatefulWidget {
  const EnterWiFiPasswordScreen({
    required this.device,
    required this.networkSsid,
    super.key,
  });

  final FF1Device device;
  final String networkSsid;

  @override
  ConsumerState<EnterWiFiPasswordScreen> createState() =>
      _EnterWiFiPasswordScreenState();
}

class _EnterWiFiPasswordScreenState
    extends ConsumerState<EnterWiFiPasswordScreen> {
  final _log = Logger('EnterWiFiPasswordScreen');
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _handleSendCredentials() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the WiFi password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Step 5 & 6: Send credentials and wait for device connection
    await ref
        .read(wifiConnectionProvider.notifier)
        .sendCredentialsAndConnect(
          device: widget.device,
          ssid: widget.networkSsid,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(wifiConnectionProvider);
    final isProcessing =
        connectionState.status != WiFiConnectionStatus.selectingNetwork &&
            connectionState.status != WiFiConnectionStatus.idle;

    // Listen for success and navigate
    ref.listen(wifiConnectionProvider, (previous, next) {
      if (next.status == WiFiConnectionStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device connected successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Navigate to connected devices screen
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      } else if (next.status == WiFiConnectionStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message ?? 'Connection failed'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter WiFi Password'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device info card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.devices,
                              color: Colors.blue[600],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.device.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${widget.device.deviceId}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Network name
                Text(
                  'WiFi Network',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi, color: Colors.blue[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.networkSsid,
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Password field
                Text(
                  'Password',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  enabled: !isProcessing,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    hintText: 'Enter WiFi password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Status message
                if (connectionState.message != null &&
                    connectionState.status != WiFiConnectionStatus.selectingNetwork &&
                    connectionState.status != WiFiConnectionStatus.idle) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: connectionState.status ==
                              WiFiConnectionStatus.error
                          ? Colors.red[50]
                          : Colors.blue[50],
                      border: Border.all(
                        color: connectionState.status ==
                                WiFiConnectionStatus.error
                            ? Colors.red[300]!
                            : Colors.blue[300]!,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (connectionState.status ==
                            WiFiConnectionStatus.error)
                          Icon(
                            Icons.error_outline,
                            color: Colors.red[600],
                          )
                        else if (connectionState.status ==
                            WiFiConnectionStatus.success)
                          Icon(
                            Icons.check_circle_outline,
                            color: Colors.green[600],
                          )
                        else
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue[600]!,
                              ),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            connectionState.message!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),

          // Send button - floating at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isProcessing ? null : _handleSendCredentials,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isProcessing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.send),
                      const SizedBox(width: 8),
                      Text(
                        isProcessing ? 'Connecting...' : 'Connect to WiFi',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
