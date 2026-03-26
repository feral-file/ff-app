import 'dart:async';

import 'package:app/app/ff1_setup/ff1_setup_effect.dart';
import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/app/providers/connect_wifi_provider.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/domain/models/wifi_point.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif_view/gif_view.dart';
import 'package:go_router/go_router.dart';

/// Payload for the enter wifi password page
class EnterWifiPasswordPagePayload {
  /// Constructor
  EnterWifiPasswordPagePayload({
    required this.device,
    required this.wifiAccessPoint,
  });

  /// The device to enter wifi password for
  final FF1Device device;

  /// The WiFi access point to enter wifi password for
  final WifiPoint wifiAccessPoint;
}

/// Screen for entering WiFi password (Step 4 of the flow)
///
/// User selects a network and enters password here
class EnterWiFiPasswordScreen extends ConsumerStatefulWidget {
  /// Constructor
  const EnterWiFiPasswordScreen({
    required this.payload,
    super.key,
  });

  /// The payload for the enter wifi password page
  final EnterWifiPasswordPagePayload payload;

  @override
  ConsumerState<EnterWiFiPasswordScreen> createState() =>
      _EnterWiFiPasswordScreenState();
}

class _EnterWiFiPasswordScreenState
    extends ConsumerState<EnterWiFiPasswordScreen> {
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  bool _isProcessing = false;
  String _passwordText = '';
  ProviderSubscription<FF1SetupState>? _setupSub;

  /// Parse SSID from networkSsid (may contain "ssid|security" format)
  String _parseSSID(String ssid) {
    if (ssid.contains('|')) {
      final parts = ssid.split('|');
      return parts.isNotEmpty ? parts.first : ssid;
    }
    return ssid;
  }

  /// Check if network is open (from "ssid|security" format)
  bool _isOpenNetwork(String ssid) {
    if (!ssid.contains('|')) {
      return false;
    }
    final parts = ssid.split('|');
    if (parts.length > 1) {
      final security = parts[1].trim().toUpperCase();
      return security == 'OPEN';
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    // Navigation + dialog side-effects must not be registered inside build.
    _setupSub = ref.listenManual<FF1SetupState>(
      ff1SetupOrchestratorProvider,
      (previous, next) {
        if (previous?.effectId == next.effectId) {
          return;
        }
        final effectId = next.effectId;
        final effect = next.effect;
        if (effect == null) {
          return;
        }
        final orchestrator = ref.read(ff1SetupOrchestratorProvider.notifier);
        unawaited(() async {
          final didHandle = await _handleOrchestratorEffect(effect);
          if (didHandle) {
            orchestrator.ackEffect(effectId: effectId);
          }
        }());
      },
    );

    final isOpen = _isOpenNetwork(widget.payload.wifiAccessPoint.ssid);
    if (isOpen) {
      // Auto-submit for open networks
      unawaited(Future.microtask(_handleSendCredentials));
    } else {
      // Request focus on password field after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _passwordFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _setupSub?.close();
    super.dispose();
  }

  Future<void> _handleSendCredentials() async {
    final isOpen = _isOpenNetwork(widget.payload.wifiAccessPoint.ssid);
    final password = isOpen ? '' : _passwordController.text.trim();

    if (!isOpen && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter the WiFi password',
            style: AppTypography.body(context).white,
          ),
          backgroundColor: AppColor.error,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Step 5 & 6: Send credentials and wait for device connection
    await ref
        .read(ff1SetupOrchestratorProvider.notifier)
        .sendWifiCredentialsAndConnect(
          device: widget.payload.device,
          ssid: _parseSSID(widget.payload.wifiAccessPoint.ssid),
          password: password,
        );
  }

  Future<bool> _handleOrchestratorEffect(FF1SetupEffect effect) async {
    switch (effect) {
      case FF1SetupNavigate(:final route, :final extra, :final method):
        if (!mounted) return false;
        switch (method) {
          case FF1SetupNavigationMethod.push:
            await context.push(route, extra: extra);
          case FF1SetupNavigationMethod.replace:
            context.replace(route, extra: extra);
          case FF1SetupNavigationMethod.go:
            context.go(route, extra: extra);
        }
        return true;
      case FF1SetupDeviceUpdating():
        if (!mounted) return false;
        context.go(Routes.ff1Updating);
        return true;
      case FF1SetupShowError(
          :final title,
          :final message,
          :final showSupportCta,
        ):
        if (!mounted) return false;
        await UIHelper.showInfoDialog(
          context,
          title,
          message,
          closeButton: showSupportCta ? 'Contact support' : '',
          onClose: showSupportCta
              ? () {
                  unawaited(
                    UIHelper.showCustomerSupport(
                      context,
                      supportEmailService: ref.read(supportEmailServiceProvider),
                    ),
                  );
                }
              : null,
        );
        if (_isOpenNetwork(widget.payload.wifiAccessPoint.ssid) && mounted) {
          context.pop();
        }
        setState(() {
          _isProcessing = false;
        });
        return true;
      case FF1SetupEnterWifiPassword():
      case FF1SetupInternetReady():
      case FF1SetupNeedsWiFi():
      case FF1SetupPop():
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(ff1SetupOrchestratorProvider);
    final connectionState = setupState.wifiState ?? const WiFiConnectionState();
    final shouldReserveNowDisplayingBar = ref.watch(
      nowDisplayingShouldShowProvider,
    );
    final isProcessing =
        _isProcessing ||
        (connectionState.status != WiFiConnectionStatus.selectingNetwork &&
            connectionState.status != WiFiConnectionStatus.idle &&
            connectionState.status != WiFiConnectionStatus.error);
    final isOpen = _isOpenNetwork(widget.payload.wifiAccessPoint.ssid);
    final parsedSsid = _parseSSID(widget.payload.wifiAccessPoint.ssid);
    // Open networks don't need a password; closed networks require one.
    final canSubmit = isOpen || _passwordText.trim().isNotEmpty;
    final reservedBottomBarHeight = shouldReserveNowDisplayingBar
        ? LayoutConstants.nowDisplayingBarReservedHeight
        : 0.0;
    final bottomInset = reservedBottomBarHeight;

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
          child: isProcessing
              ? _buildProcessingView(parsedSsid)
              : isOpen
              ? const SizedBox()
              : Stack(
                  children: [
                    CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height:
                                LayoutConstants.space6 + LayoutConstants.space2,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                parsedSsid,
                                style: AppTypography.body(context).white,
                              ),
                              SizedBox(height: LayoutConstants.space4),
                              PasswordTextField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                style: AppTypography.body(context).white,
                                hintText: 'Password',
                                defaultObscure: false,
                                isEnabled: !isProcessing,
                                onChanged: (v) =>
                                    setState(() => _passwordText = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: LayoutConstants.space4 + bottomInset,
                      left: 0,
                      right: 0,
                      child: PrimaryAsyncButton(
                        key: GoldPathPatrolKeys.wifiPasswordSubmit,
                        padding: EdgeInsets.symmetric(
                          vertical:
                              LayoutConstants.space3 + LayoutConstants.space1,
                        ),
                        color: PrimitivesTokens.colorsWhite,
                        onTap: canSubmit ? _handleSendCredentials : null,
                        text: 'Submit',
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildProcessingView(String ssid) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GifView.asset(
            'assets/images/loading.gif',
            width: 139,
            height: 92.67,
            frameRate: 12,
          ),
          SizedBox(height: LayoutConstants.space16),
          Text.rich(
            TextSpan(
              style: AppTypography.body(context).white.regular,
              children: [
                const TextSpan(
                  text: 'Connecting to ',
                ),
                TextSpan(
                  text: ssid,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text: '...',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// PasswordTextField widget - to enter password, with button to change visibility
class PasswordTextField extends StatefulWidget {
  const PasswordTextField({
    required this.controller,
    super.key,
    this.defaultObscure = true,
    this.style,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onVisibilityChanged,
    this.isEnabled = true,
    this.focusNode,
  });

  final TextEditingController controller;
  final TextStyle? style;
  final bool defaultObscure;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<bool>? onVisibilityChanged;
  final bool isEnabled;
  final FocusNode? focusNode;

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  late bool _isObscure;

  @override
  void initState() {
    super.initState();
    _isObscure = widget.defaultObscure;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: widget.focusNode,
      autocorrect: false,
      enableSuggestions: false,
      controller: widget.controller,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      obscureText: _isObscure,
      style: widget.style,
      enabled: widget.isEnabled,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: widget.style,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        fillColor: AppColor.primaryBlack,
        focusColor: AppColor.primaryBlack,
        filled: true,
        constraints: BoxConstraints(
          minHeight:
              LayoutConstants.minTouchTarget +
              LayoutConstants.space4 +
              LayoutConstants.space4,
        ),
        contentPadding: EdgeInsets.symmetric(
          vertical: LayoutConstants.space6,
          horizontal: LayoutConstants.space4,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isObscure ? Icons.visibility_off : Icons.visibility,
            color: AppColor.greyMedium,
            size: LayoutConstants.iconSizeMedium,
          ),
          onPressed: () {
            setState(() {
              _isObscure = !_isObscure;
              widget.onVisibilityChanged?.call(_isObscure);
            });
          },
        ),
      ),
    );
  }
}
