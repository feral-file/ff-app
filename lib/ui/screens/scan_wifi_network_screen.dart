import 'package:app/app/providers/ff1_connection_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/send_wifi_credentials_screen.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen for scanning and selecting WiFi networks
class ScanWiFiNetworkScreen extends ConsumerStatefulWidget {
  const ScanWiFiNetworkScreen({required this.device, super.key});

  final FF1Device device;

  @override
  ConsumerState<ScanWiFiNetworkScreen> createState() =>
      _ScanWiFiNetworkScreenState();
}

class _ScanWiFiNetworkScreenState extends ConsumerState<ScanWiFiNetworkScreen> {
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
      backgroundColor: AppColor.auGreyBackground,
      appBar: AppBar(
        backgroundColor: AppColor.auGreyBackground,
        title: Text(
          'Select WiFi network',
          style: AppTypography.h4(context).white,
        ),
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
              size: LayoutConstants.space16,
              color: AppColor.auQuickSilver,
            ),
            SizedBox(height: LayoutConstants.space4),
            Text(
              'No WiFi Networks Found',
              style: AppTypography.h3(context).white,
            ),
            SizedBox(height: LayoutConstants.space2),
            Text(
              'Make sure your WiFi network is visible',
              style: AppTypography.body(context).grey,
            ),
            SizedBox(height: LayoutConstants.space6),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Go back',
                style: AppTypography.body(context).white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(LayoutConstants.space4),
      itemCount: networks.length,
      itemBuilder: (context, index) {
        final network = networks[index];
        return Card(
          margin: EdgeInsets.only(bottom: LayoutConstants.space3),
          child: ListTile(
            leading: Icon(
              Icons.wifi,
              color: AppColor.feralFileLightBlue,
            ),
            title: Text(
              network.ssid,
              style: AppTypography.body(context).white,
            ),
            trailing: const Icon(Icons.arrow_forward, color: AppColor.white),
            onTap: () {
              ref.read(wifiConnectionProvider.notifier).selectNetwork(network);
              // Navigate to password entry screen
              Navigator.of(context).push(
                MaterialPageRoute<void>(
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
        child: LoadingWidget(
          backgroundColor: AppColor.auGreyBackground,
          text: state.message ?? 'Scanning networks...',
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
              size: LayoutConstants.space16,
              color: AppColor.error,
            ),
            SizedBox(height: LayoutConstants.space4),
            Text(
              'Error Scanning Networks',
              style: AppTypography.h3(context).white,
            ),
            SizedBox(height: LayoutConstants.space2),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: LayoutConstants.space6,
              ),
              child: Text(
                state.message ?? 'An unexpected error occurred',
                textAlign: TextAlign.center,
                style: AppTypography.body(context).grey,
              ),
            ),
            SizedBox(height: LayoutConstants.space6),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Go back',
                style: AppTypography.body(context).white,
              ),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: LoadingView(),
    );
  }
}
