import 'dart:async';

import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_providers.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/wifi_point.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/send_wifi_credentials_screen.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:app/widgets/section_expanded_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Payload for the scan wifi network page
class ScanWifiNetworkPagePayload {
  /// Constructor
  ScanWifiNetworkPagePayload({
    required this.device,
  });

  /// The device to scan wifi networks for
  final FF1Device device;
}

/// Screen for scanning and selecting WiFi networks
class ScanWiFiNetworkScreen extends ConsumerStatefulWidget {
  /// Constructor
  const ScanWiFiNetworkScreen({
    required this.payload,
    super.key,
  });

  /// The payload for the scan wifi network page
  final ScanWifiNetworkPagePayload payload;

  @override
  ConsumerState<ScanWiFiNetworkScreen> createState() =>
      _ScanWiFiNetworkScreenState();
}

class _ScanWiFiNetworkScreenState extends ConsumerState<ScanWiFiNetworkScreen> {
  final TextEditingController _ssidController = TextEditingController();
  bool _shouldEnableConnectButton = false;

  @override
  void initState() {
    super.initState();
    // Start scanning for networks
    Future.microtask(() {
      unawaited(
        ref
            .read(connectWiFiProvider.notifier)
            .connectAndScanNetworks(
              device: widget.payload.device,
            ),
      );
    });
  }

  @override
  void dispose() {
    _ssidController.dispose();
    super.dispose();
  }

  /// Parse SSID from scan result (may contain "ssid|security" format)
  String _parseSSID(String result) {
    if (result.contains('|')) {
      final parts = result.split('|');
      return parts.isNotEmpty ? parts.first : result;
    }
    return result;
  }

  /// Check if network is open (from "ssid|security" format)
  bool _isOpenNetwork(String result) {
    if (!result.contains('|')) {
      return false;
    }
    final parts = result.split('|');
    if (parts.length > 1) {
      final security = parts[1].trim().toUpperCase();
      return security == 'OPEN';
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectWiFiProvider);
    final isScanning =
        connectionState.status == WiFiConnectionStatus.connecting ||
        connectionState.status == WiFiConnectionStatus.scanningNetworks;
    final hasError = connectionState.status == WiFiConnectionStatus.error;
    final networks = connectionState.scannedNetworks ?? [];

    return Scaffold(
      appBar: const SetupAppBar(
        title: 'Select Network',
      ),
      backgroundColor: PrimitivesTokens.colorsDarkGrey,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: LayoutConstants.setupPageHorizontal,
          ),
          child: KeyboardVisibilityBuilder(
            builder: (context, isKeyboardVisible) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: LayoutConstants.space6 + LayoutConstants.space2,
                    ),
                  ),
                  if (isScanning) ...[
                    SliverToBoxAdapter(
                      child: Text(
                        'Getting WiFi networks from your FF1. Please wait a moment...',
                        style: AppTypography.body(context).white,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(height: LayoutConstants.space6),
                    ),
                  ] else ...[
                    if (hasError || networks.isEmpty)
                      SliverToBoxAdapter(
                        child: _errorOrEmptyView(context, connectionState),
                      ),
                  ],
                  if (networks.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _listWifiView(context, networks, connectionState),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: LayoutConstants.space10,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _errorOrEmptyView(
    BuildContext context,
    WiFiConnectionState connectionState,
  ) {
    final hasError = connectionState.status == WiFiConnectionStatus.error;

    final String title;
    final String description;

    if (hasError) {
      if (connectionState.isConnectionFailed) {
        title = 'Could not connect to FF1';
        description =
            'Make sure your FF1 is powered on and within Bluetooth range, '
            'then retry.';
      } else {
        title = 'Cannot get available networks from FF1';
        description =
            connectionState.message ??
            'There might be an issue with the WiFi module on your FF1. '
                'Try restarting your FF1 and scan again.';
      }
    } else {
      title = 'No WiFi networks found by FF1';
      description = 'Make sure WiFi networks are available nearby, then retry.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.caption(context).bold.white),
        SizedBox(height: LayoutConstants.space2),
        Text(description, style: AppTypography.body(context).white),
        SizedBox(height: LayoutConstants.space5),
        PrimaryButton(
          onTap: () {
            unawaited(
              ref
                  .read(connectWiFiProvider.notifier)
                  .connectAndScanNetworks(device: widget.payload.device),
            );
          },
          text: 'Try again',
        ),
      ],
    );
  }

  Widget _listWifiView(
    BuildContext context,
    List<WiFiNetwork> networks,
    WiFiConnectionState connectionState,
  ) {
    return Column(
      children: [
        Text(
          '''To avoid overloading the BLE connection, only the strongest nearby Wi-Fi networks are shown. '''
          '''If your network isn't listed, try moving the device closer to your Wi-Fi router, or connect manually.''',
          style: AppTypography.body(context).white,
        ),
        SizedBox(height: LayoutConstants.space20),
        ...networks.map(
          (network) => _networkItem(context, network),
        ),
        _otherNetworkItem(context),
      ],
    );
  }

  Widget _networkItem(BuildContext context, WiFiNetwork network) {
    // Parse SSID and check if open (if scan result contains security info)
    final ssid = _parseSSID(network.ssid);
    final isOpen = _isOpenNetwork(network.ssid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () async {
            ref.read(connectWiFiProvider.notifier).selectNetwork(network);
            final connected = await ref.read(
              connectedBlDeviceForNameProvider(widget.payload.device.name).future,
            );
            final deviceToPass = connected != null
                ? widget.payload.device.copyWith(
                    remoteId: connected.remoteId.str,
                  )
                : widget.payload.device;
            if (!context.mounted) return;
            unawaited(
              context.push(
                Routes.enterWifiPassword,
                extra: EnterWifiPasswordPagePayload(
                  device: deviceToPass,
                  wifiAccessPoint: WifiPoint(ssid),
                ),
              ),
            );
          },
          child: SizedBox(
            width: double.infinity,
            child: ColoredBox(
              color: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: LayoutConstants.space3,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        ssid,
                        style: AppTypography.body(context).white,
                      ),
                    ),
                    if (!isOpen)
                      Icon(
                        Icons.lock,
                        color: AppColor.white,
                        size: LayoutConstants.iconSizeMedium,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const Divider(
          color: AppColor.primaryBlack,
        ),
      ],
    );
  }

  Widget _otherNetworkItem(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionExpandedWidget(
          header: 'Other network',
          headerStyle: AppTypography.body(context).white,
          withDivider: false,
          headerPadding: EdgeInsets.symmetric(
            vertical: LayoutConstants.space3,
          ),
          iconOnUnExpanded: Icon(
            Icons.arrow_forward_ios,
            size: LayoutConstants.iconSizeSmall,
            color: AppColor.white,
          ),
          iconOnExpanded: RotatedBox(
            quarterTurns: 1,
            child: Icon(
              Icons.arrow_forward_ios,
              color: AppColor.white,
              size: LayoutConstants.iconSizeSmall,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Network name (SSID)',
                style: AppTypography.body(context).white,
              ),
              SizedBox(height: LayoutConstants.space4),
              TextField(
                controller: _ssidController,
                decoration: InputDecoration(
                  hintText: 'Enter wifi network',
                  hintStyle: AppTypography.body(context).white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      LayoutConstants.space2 + LayoutConstants.space1,
                    ),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: AppColor.primaryBlack,
                  focusColor: AppColor.primaryBlack,
                  filled: true,
                  constraints: BoxConstraints(
                    minHeight:
                        LayoutConstants.minTouchTarget + LayoutConstants.space4,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: LayoutConstants.space6,
                    horizontal: LayoutConstants.space4,
                  ),
                ),
                style: AppTypography.body(context).white,
                onChanged: (value) {
                  if (mounted) {
                    setState(() {
                      _shouldEnableConnectButton = value.trim().isNotEmpty;
                    });
                  }
                },
              ),
              SizedBox(height: LayoutConstants.space6),
              PrimaryButton(
                enabled: _shouldEnableConnectButton,
                onTap: () async {
                  final ssid = _ssidController.text.trim();
                  if (ssid.isEmpty) {
                    return;
                  }
                  // Create a WiFiNetwork for the manually entered SSID
                  final network = WiFiNetwork(ssid);
                  ref.read(connectWiFiProvider.notifier).selectNetwork(network);
                  final connected = await ref.read(
                    connectedBlDeviceForNameProvider(
                      widget.payload.device.name,
                    ).future,
                  );
                  final deviceToPass = connected != null
                      ? widget.payload.device.copyWith(
                          remoteId: connected.remoteId.str,
                        )
                      : widget.payload.device;
                  if (!context.mounted) return;
                  unawaited(
                    context.push(
                      Routes.enterWifiPassword,
                      extra: EnterWifiPasswordPagePayload(
                        device: deviceToPass,
                        wifiAccessPoint: WifiPoint(ssid),
                      ),
                    ),
                  );
                },
                text: 'Continue',
              ),
              SizedBox(height: LayoutConstants.space4),
            ],
          ),
        ),
        const Divider(
          color: AppColor.primaryBlack,
        ),
      ],
    );
  }
}
