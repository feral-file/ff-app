import 'package:app/app/providers/ff1_connection_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/ui/screens/send_wifi_credentials_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Screen for scanning and selecting WiFi networks
class ScanWiFiNetworkScreen extends ConsumerStatefulWidget {
  const ScanWiFiNetworkScreen({required this.device, super.key});

  final FF1Device device;

  @override
  ConsumerState<ScanWiFiNetworkScreen> createState() =>
      _ScanWiFiNetworkScreenState();
}

class _ScanWiFiNetworkScreenState extends ConsumerState<ScanWiFiNetworkScreen> {
  final _log = Logger('ScanWiFiNetworkScreen');

  @override
  void initState() {
    super.initState();
    // Start scanning for networks
    Future.microtask(() {
      ref.read(wifiConnectionProvider.notifier).connectAndScanNetworks(
            device: widget.device,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(wifiConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select WiFi Network'),
        elevation: 0,
      ),
      body: connectionState.status == WiFiConnectionStatus.selectingNetwork &&
              connectionState.scannedNetworks != null
          ? _buildNetworkList(context, connectionState, ref)
          : _buildLoadingOrError(context, connectionState),
    );
  }

  Widget _buildNetworkList(
    BuildContext context,
    WiFiConnectionState state,
    WidgetRef ref,
  ) {
    final networks = state.scannedNetworks ?? [];

    if (networks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No WiFi Networks Found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure your WiFi network is visible',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: networks.length,
      itemBuilder: (context, index) {
        final network = networks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              Icons.wifi,
              color: Colors.blue[600],
            ),
            title: Text(network.ssid),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              ref.read(wifiConnectionProvider.notifier).selectNetwork(network);
              // Navigate to password entry screen
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EnterWiFiPasswordScreen(
                    device: widget.device,
                    networkSsid: network.ssid,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLoadingOrError(
    BuildContext context,
    WiFiConnectionState state,
  ) {
    if (state.status == WiFiConnectionStatus.connecting ||
        state.status == WiFiConnectionStatus.scanningNetworks) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              state.message ?? 'Scanning networks...',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (state.status == WiFiConnectionStatus.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error Scanning Networks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                state.message ?? 'An unexpected error occurred',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}
