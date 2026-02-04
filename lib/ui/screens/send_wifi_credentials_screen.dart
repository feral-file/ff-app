import 'package:app/app/providers/ff1_connection_providers.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        SnackBar(
          content: Text(
            'WiFi password is required to connect.',
            style: AppTypography.body(context).white,
          ),
          backgroundColor: AppColor.error,
        ),
      );
      return;
    }

    // Step 5 & 6: Send credentials and wait for device connection
    await ref.read(wifiConnectionProvider.notifier).sendCredentialsAndConnect(
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
          SnackBar(
            content: Text(
              'Device connected.',
              style: AppTypography.body(context).white,
            ),
            backgroundColor: AppColor.primaryBlack,
            duration: const Duration(seconds: 2),
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
            content: Text(
              next.message ?? 'Connection failed.',
              style: AppTypography.body(context).white,
            ),
            backgroundColor: AppColor.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: AppBar(
        backgroundColor: AppColor.auGreyBackground,
        title: Text(
          'Enter WiFi password',
          style: AppTypography.h4(context).white,
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(LayoutConstants.space6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Device info card
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(LayoutConstants.space4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.devices,
                              color: AppColor.feralFileLightBlue,
                              size: LayoutConstants.iconSizeLarge,
                            ),
                            SizedBox(width: LayoutConstants.space3),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.device.name,
                                    style: AppTypography.h4(context).white,
                                  ),
                                  SizedBox(height: LayoutConstants.space1),
                                  Text(
                                    'ID: ${widget.device.deviceId}',
                                    style: AppTypography.bodySmall(context).grey,
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
                SizedBox(height: LayoutConstants.space8),

                // Network name
                Text(
                  'WiFi Network',
                  style: AppTypography.h4(context).white,
                ),
                SizedBox(height: LayoutConstants.space2),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(LayoutConstants.space3),
                  decoration: BoxDecoration(
                    color: AppColor.auLightGrey,
                    border: Border.all(color: AppColor.auGrey),
                    borderRadius: BorderRadius.circular(LayoutConstants.space2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi, color: AppColor.feralFileLightBlue),
                      SizedBox(width: LayoutConstants.space3),
                      Expanded(
                        child: Text(
                          widget.networkSsid,
                          style: AppTypography.body(context).black,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: LayoutConstants.space6),

                // Password field
                Text(
                  'Password',
                  style: AppTypography.h4(context).white,
                ),
                SizedBox(height: LayoutConstants.space2),
                TextField(
                  controller: _passwordController,
                  enabled: !isProcessing,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    hintText: 'Enter WiFi password',
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(LayoutConstants.space2),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
                      },
                    ),
                  ),
                ),
                SizedBox(height: LayoutConstants.space8),

                // Status message
                if (connectionState.message != null &&
                    connectionState.status !=
                        WiFiConnectionStatus.selectingNetwork &&
                    connectionState.status != WiFiConnectionStatus.idle) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(LayoutConstants.space4),
                    decoration: BoxDecoration(
                      color:
                          connectionState.status == WiFiConnectionStatus.error
                              ? AppColor.lightRed
                              : AppColor.feralFileLightBlue,
                      border: Border.all(
                        color:
                            connectionState.status == WiFiConnectionStatus.error
                                ? AppColor.error
                                : AppColor.feralFileLightBlue,
                      ),
                      borderRadius:
                          BorderRadius.circular(LayoutConstants.space2),
                    ),
                    child: Row(
                      children: [
                        if (connectionState.status ==
                            WiFiConnectionStatus.error)
                          Icon(
                            Icons.error_outline,
                            color: AppColor.error,
                          )
                        else if (connectionState.status ==
                            WiFiConnectionStatus.success)
                          Icon(
                            Icons.check_circle_outline,
                            color: AppColor.feralFileHighlight,
                          )
                        else
                          loadingIndicator(
                            valueColor: AppColor.primaryBlack,
                            size: LayoutConstants.iconSizeMedium,
                          ),
                        SizedBox(width: LayoutConstants.space3),
                        Expanded(
                          child: Text(
                            connectionState.message!,
                            style: AppTypography.bodySmall(context).black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: LayoutConstants.space6),
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
                color: AppColor.white,
              ),
              padding: EdgeInsets.all(LayoutConstants.space6),
              child: SizedBox(
                width: double.infinity,
                height: LayoutConstants.space12,
                child: ElevatedButton(
                  onPressed: isProcessing ? null : _handleSendCredentials,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isProcessing)
                        loadingIndicator(
                          valueColor: AppColor.white,
                          size: LayoutConstants.iconSizeMedium,
                        )
                      else
                        const Icon(Icons.send, color: AppColor.white),
                      SizedBox(width: LayoutConstants.space2),
                      Text(
                        isProcessing ? 'Connecting...' : 'Connect to WiFi',
                        style: AppTypography.body(context).white,
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
