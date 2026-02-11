// import 'dart:async';

// import 'package:after_layout/after_layout.dart';
// import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
// import 'package:app/app/providers/ff1_connection_providers.dart';
// import 'package:app/app/providers/ff1_wifi_providers.dart';
// import 'package:app/design/app_typography.dart';
// import 'package:app/design/build/primitives.dart';
// import 'package:app/design/layout_constants.dart';
// import 'package:app/domain/models/ff1_device.dart';
// import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
// import 'package:app/theme/app_color.dart';
// import 'package:app/widgets/appbars/setup_app_bar.dart';
// import 'package:app/widgets/buttons/primary_button.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:go_router/go_router.dart';
// import 'package:logging/logging.dart';

// enum ScreenOrientation {
//   landscape,
//   landscapeReverse,
//   portrait,
//   portraitReverse;

//   String get name {
//     switch (this) {
//       case ScreenOrientation.landscape:
//         return 'landscape';
//       case ScreenOrientation.landscapeReverse:
//         return 'landscapeReverse';
//       case ScreenOrientation.portrait:
//         return 'portrait';
//       case ScreenOrientation.portraitReverse:
//         return 'portraitReverse';
//     }
//   }

//   static ScreenOrientation fromString(String value) {
//     switch (value) {
//       case 'landscape':
//       case 'normal':
//         return ScreenOrientation.landscape;
//       case 'landscapeReverse':
//       case 'inverted':
//         return ScreenOrientation.landscapeReverse;
//       case 'portrait':
//       case 'left':
//         return ScreenOrientation.portrait;
//       case 'portraitReverse':
//       case 'right':
//         return ScreenOrientation.portraitReverse;
//       default:
//         throw ArgumentError('Invalid screen orientation: $value');
//     }
//   }
// }

// class DeviceConfigPayload {
//   DeviceConfigPayload({
//     this.isFromOnboarding = false,
//   });

//   final bool isFromOnboarding;
// }

// class DeviceConfigScreen extends ConsumerStatefulWidget {
//   const DeviceConfigScreen({required this.payload, super.key});

//   final DeviceConfigPayload payload;

//   @override
//   ConsumerState<DeviceConfigScreen> createState() =>
//       DeviceConfigState();
// }

// class DeviceConfigState
//     extends ConsumerState<DeviceConfigScreen>
//     with
//         RouteAware,
//         WidgetsBindingObserver,
//         AfterLayoutMixin<DeviceConfigScreen> {
//   // Device from Riverpod
//   FF1Device? _ff1Device;

//   // Device status from WiFi control (if device has topicId and is connected via WiFi)
//   FF1DeviceStatus? _deviceStatus;

//   // Connection state
//   bool _isDeviceConnected = false;

//   // UI state
//   bool _isShowingFirmwareUpdateDialog = false;
//   bool _didCheckFirmwareUpdateDialog = false;

//   static final _log = Logger('BluetoothConnectedDeviceConfig');

//   // Add performance metrics tracking
//   final List<FlSpot> _cpuPoints = [];
//   final List<FlSpot> _memoryPoints = [];
//   final List<FlSpot> _gpuPoints = [];
//   Timer? _metricsUpdateTimer;

//   final int _maxDataPoints = 20;

//   // Add temperature metrics tracking
//   final List<FlSpot> _cpuTempPoints = [];
//   final List<FlSpot> _gpuTempPoints = [];

//   // Add FPS metrics tracking
//   final List<FlSpot> _fpsPoints = [];

//   // TODO: Re-implement metrics when DeviceRealtimeMetrics is available
//   // DeviceRealtimeMetrics? _latestMetrics;
//   dynamic _latestMetrics;

//   // StreamSubscription<DeviceRealtimeMetrics>? _metricsStreamSubscription;
//   StreamSubscription<dynamic>? _metricsStreamSubscription;

//   // StreamSubscription<FGBGType>? _fgbgSubscription;
//   StreamSubscription<dynamic>? _fgbgSubscription;

//   bool _isShowingQRCode = false;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//   }

//   /// Setup device from FF1Device
//   void _setupDeviceFromFF1(FF1Device device) {
//     _ff1Device = device;

//     // Check if device has WiFi connection (has topicId)
//     if (device.topicId != null && device.topicId!.isNotEmpty) {
//       // Device can be connected via WiFi - check connection status
//       final wifiControl = ref.read(ff1WifiControlProvider);
//       _isDeviceConnected = wifiControl.isConnected &&
//           wifiControl.currentDeviceStatus != null;
//       _deviceStatus = wifiControl.currentDeviceStatus;
//     } else {
//       // Device only has BLE connection
//       _isDeviceConnected = false;
//       _deviceStatus = null;
//     }

//     setState(() {});
//   }

//   @override
//   void afterFirstLayout(BuildContext context) {
//     if (widget.payload.isFromOnboarding) {
//       // If this screen is opened from onboarding, we don't need to enable metrics streaming
//       return;
//     }

//     // Listen to device status stream if device has WiFi connection
//     if (_ff1Device?.topicId != null && _ff1Device!.topicId!.isNotEmpty) {
//       _listenToDeviceStatus();
//     }

//     unawaited(
//       Future<void>.delayed(
//         const Duration(seconds: 3),
//         _maybeShowFirmwareUpdateDialog,
//       ),
//     );
//   }

//   /// Listen to device status updates from WiFi control
//   void _listenToDeviceStatus() {
//     if (_ff1Device == null || _ff1Device!.topicId == null) return;

//     // Watch device status stream
//     ref.listen<AsyncValue<FF1DeviceStatus>>(
//       ff1DeviceStatusStreamProvider,
//       (previous, next) {
//         next.whenData((status) {
//           if (mounted) {
//             setState(() {
//               _deviceStatus = status;
//               _isDeviceConnected = true;
//             });
//           }

//           if (!widget.payload.isFromOnboarding) {
//             unawaited(_maybeShowFirmwareUpdateDialog());
//           }
//         });
//       },
//     );
//   }

//   Future<void> _maybeShowFirmwareUpdateDialog() async {
//     if (!mounted) return;
//     if (_isShowingFirmwareUpdateDialog) return;
//     if (_didCheckFirmwareUpdateDialog) return;

//     final status = _deviceStatus;
//     if (status == null) return;

//     final latestVersion = status.latestVersion;
//     final installedVersion = status.installedVersion;

//     if (latestVersion == null || installedVersion == null) return;
//     if (latestVersion == installedVersion) return;

//     // TODO: Implement firmware update dialog using project's navigation system
//     // For now, just log the update availability
//     _log.info('Firmware update available: $installedVersion -> $latestVersion');
//     _didCheckFirmwareUpdateDialog = true;
//   }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     // TODO: Implement route observer if needed
//     // routeObserver.subscribe(this, ModalRoute.of(context)!);
//   }

//   @override
//   void dispose() {
//     _metricsUpdateTimer?.cancel();
//     _metricsStreamSubscription?.cancel();
//     WidgetsBinding.instance.removeObserver(this);
//     // TODO: Implement route observer if needed
//     // routeObserver.unsubscribe(this);
//     _stopMetricsStreaming();
//     _fgbgSubscription?.cancel();
//     super.dispose();
//   }

//   @override
//   void didPushNext() {
//     // Called when another route has been pushed on top of this one
//     super.didPushNext();
//   }

//   @override
//   void didPopNext() {
//     // Called when coming back to this route
//     super.didPopNext();
//     // Re-enable metrics streaming when returning to this screen
//     // _enableMetricsStreaming();
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Watch active device - Riverpod will automatically fetch and update
//     final activeDeviceAsync = ref.watch(activeFF1BluetoothDeviceProvider);

//     // Listen for device changes and setup accordingly
//     ref.listen<AsyncValue<FF1Device?>>(
//       activeFF1BluetoothDeviceProvider,
//       (previous, next) {
//         next.whenData((device) {
//           if (device != null) {
//             // Device found - setup if changed
//             if (device.deviceId != _ff1Device?.deviceId) {
//               _setupDeviceFromFF1(device);
//               // Listen to device status if device has WiFi connection
//               if (device.topicId != null && device.topicId!.isNotEmpty) {
//                 _listenToDeviceStatus();
//               }
//             }
//           } else {
//             // No active device
//             _ff1Device = null;
//             _deviceStatus = null;
//             _isDeviceConnected = false;
//             setState(() {});
//           }
//         });
//       },
//     );

//     // Use Riverpod's built-in loading/error handling
//     return activeDeviceAsync.when(
//       loading: () => Scaffold(
//         backgroundColor: AppColor.auGreyBackground,
//         body: const Center(
//           child: CircularProgressIndicator(),
//         ),
//       ),
//       error: (error, stack) => Scaffold(
//         backgroundColor: AppColor.auGreyBackground,
//         appBar: AppBar(
//           title: const Text('Error'),
//         ),
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(
//                 Icons.error_outline,
//                 size: 64,
//                 color: Colors.red[400],
//               ),
//               SizedBox(height: LayoutConstants.space4),
//               Text(
//                 'Failed to load device',
//                 style: AppTypography.body(context).white,
//               ),
//             ],
//           ),
//         ),
//       ),
//       data: (device) {
//         // Setup device on first load or when device changes
//         if (device != null && device.deviceId != _ff1Device?.deviceId) {
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             _setupDeviceFromFF1(device);
//             // Listen to device status if device has WiFi connection
//             if (device.topicId != null && device.topicId!.isNotEmpty) {
//               _listenToDeviceStatus();
//             }
//           });
//         }

//         if (device == null && _ff1Device == null) {
//           return Scaffold(
//             backgroundColor: AppColor.auGreyBackground,
//             appBar: AppBar(
//               title: const Text('Device Not Found'),
//             ),
//             body: Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.device_unknown,
//                     size: 64,
//                     color: Colors.grey[400],
//                   ),
//                   SizedBox(height: LayoutConstants.space4),
//                   Text(
//                     'Device not found',
//                     style: AppTypography.body(context).white,
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }

//         final name = _ff1Device?.name ?? device?.name ?? 'Unknown Device';
//     return Scaffold(
//       appBar: SetupAppBar(
//         title: name,
//         hasBackButton: !widget.payload.isFromOnboarding,
//         onBack: widget.payload.isFromOnboarding
//             ? null
//             : () {
//                 context.pop();
//               },
//         actions: widget.payload.isFromOnboarding
//             ? []
//             : [
//                 _buildDeviceSwitcher(context),
//                 Container(
//                   padding: EdgeInsets.all(LayoutConstants.space2).copyWith(
//                     left: LayoutConstants.space3 + LayoutConstants.space2,
//                   ),
//                   child: GestureDetector(
//                     onTap: () {
//                       _showOption(context);
//                     },
//                     child: SvgPicture.asset(
//                       'assets/images/more_circle.svg',
//                       width: LayoutConstants.iconSizeMedium,
//                       colorFilter: const ColorFilter.mode(
//                         AppColor.white,
//                         BlendMode.srcIn,
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//       ),
//       backgroundColor: AppColor.auGreyBackground,
//       body: SafeArea(child: _body(context)),
//     );
//       },
//     );
//   }

//   Widget _body(BuildContext context) {
//     return Stack(
//       children: [
//         _deviceConfig(context),
//         if (widget.payload.isFromOnboarding)
//           Positioned(
//             bottom: LayoutConstants.space4,
//             left: LayoutConstants.space3,
//             right: LayoutConstants.space3,
//             child: PrimaryAsyncButton(
//               padding: const EdgeInsets.only(top: 13, bottom: 10),
//               onTap: () async {
//                 // TODO: Navigate to home using GoRouter
//                 context.go('/');
//               },
//               text: 'Finish',
//               color: PrimitivesTokens.colorsLightBlue,
//             ),
//           ),
//         if (widget.payload.isFromOnboarding && !_isDeviceConnected)
//           Positioned.fill(
//             child: Consumer(
//               builder: (context, ref, child) {
//                 // Watch device connection status
//                 final isConnected = _ff1Device?.topicId != null
//                     ? ref.watch(ff1DeviceConnectedProvider)
//                     : false;

//                 return AnimatedOpacity(
//                   opacity: isConnected ? 0.0 : 1.0,
//                   duration: const Duration(milliseconds: 500),
//                   child: Container(
//                     color: Colors.black.withOpacity(0.8),
//                     child: Center(
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const CircularProgressIndicator(),
//                           SizedBox(height: LayoutConstants.space4),
//                           Text(
//                             'FF1 is getting ready',
//                             style: AppTypography.body(context).white,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _deviceConfig(BuildContext context) {
//     final isFromOnboarding = widget.payload.isFromOnboarding;
//     return Consumer(
//       builder: (context, ref, child) {
//         // Check device connection status
//         final isDeviceConnected = _ff1Device?.topicId != null
//             ? ref.watch(ff1DeviceConnectedProvider) && _deviceStatus != null
//             : false;
//         return Padding(
//           padding: EdgeInsets.zero,
//           child: CustomScrollView(
//             slivers: [
//               SliverToBoxAdapter(
//                 child: SizedBox(
//                   height: MediaQuery.paddingOf(context).top + 32,
//                 ),
//               ),
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(
//                     horizontal: LayoutConstants.pageHorizontalDefault,
//                   ),
//                   child: _displayOrientation(context),
//                 ),
//               ),
//               SliverToBoxAdapter(
//                 child: Divider(
//                   color: AppColor.primaryBlack,
//                   thickness: 1,
//                   height: LayoutConstants.space10,
//                 ),
//               ),
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: EdgeInsets.symmetric(
//                     horizontal: LayoutConstants.pageHorizontalDefault,
//                   ),
//                   child: _canvasSetting(context),
//                 ),
//               ),
//               SliverToBoxAdapter(
//                 child: SizedBox(
//                   height: LayoutConstants.space5,
//                 ),
//               ),
//               const SliverToBoxAdapter(
//                 child: Divider(
//                   color: AppColor.primaryBlack,
//                   thickness: 1,
//                   height: 1,
//                 ),
//               ),
//               if (!isFromOnboarding) ...[
//                 const SliverToBoxAdapter(
//                   child: SizedBox(
//                     height: 20,
//                   ),
//                 ),
//                 SliverToBoxAdapter(
//                   child: Padding(
//                     padding: EdgeInsets.symmetric(
//                     horizontal: LayoutConstants.pageHorizontalDefault,
//                   ),
//                     child: _deviceInfo(context),
//                   ),
//                 ),

//                 // Add performance monitoring section
//                 const SliverToBoxAdapter(
//                   child: Divider(
//                     color: AppColor.primaryBlack,
//                     thickness: 1,
//                     height: 40,
//                   ),
//                 ),
//                 if (isDeviceConnected) ...[
//                   SliverToBoxAdapter(
//                     child: Padding(
//                       padding: EdgeInsets.symmetric(
//                     horizontal: LayoutConstants.pageHorizontalDefault,
//                   ),
//                       child: _performanceMonitoring(context),
//                     ),
//                   ),

//                   // Temperature monitoring section
//                   const SliverToBoxAdapter(
//                     child: Divider(
//                       color: AppColor.primaryBlack,
//                       thickness: 1,
//                       height: 40,
//                     ),
//                   ),
//                 ],
//                 if (isDeviceConnected) ...[
//                   SliverToBoxAdapter(
//                     child: Padding(
//                       padding: EdgeInsets.symmetric(
//                     horizontal: LayoutConstants.pageHorizontalDefault,
//                   ),
//                       child: _temperatureMonitoring(context),
//                     ),
//                   ),
//                   const SliverToBoxAdapter(
//                     child: Divider(
//                       color: AppColor.primaryBlack,
//                       thickness: 1,
//                       height: 40,
//                     ),
//                   ),
//                 ],
//                 SliverToBoxAdapter(
//                   child: SizedBox(
//                     height: LayoutConstants.space12,
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         );
//       },
//     );
//   }

//   Widget _displayOrientationPreview(ScreenOrientation? screenOrientation) {
//     return Container(
//       decoration: BoxDecoration(
//         color: AppColor.primaryBlack,
//         borderRadius: BorderRadius.circular(10),
//       ),
//       height: 200,
//       child: Center(
//         child: _displayOrientationPreviewImage(
//           screenOrientation,
//         ),
//       ),
//     );
//   }

//   Widget _displayOrientationPreviewImage(ScreenOrientation? screenOrientation) {
//     if (screenOrientation == null) {
//       return const SizedBox.shrink();
//     }
//     switch (screenOrientation) {
//       case ScreenOrientation.landscape:
//         return SvgPicture.asset(
//           'assets/images/landscape.svg',
//           width: 150,
//         );
//       case ScreenOrientation.landscapeReverse:
//         return RotatedBox(
//           quarterTurns: 2,
//           child: SvgPicture.asset(
//             'assets/images/landscape.svg',
//             width: 150,
//           ),
//         );
//       case ScreenOrientation.portrait:
//         return SvgPicture.asset(
//           'assets/images/portrait.svg',
//           height: 150,
//         );
//       case ScreenOrientation.portraitReverse:
//         return RotatedBox(
//           quarterTurns: 2,
//           child: SvgPicture.asset(
//             'assets/images/portrait.svg',
//             height: 150,
//           ),
//         );
//     }
//   }

//   Widget _displayOrientation(BuildContext context) {
//     if (_ff1Device == null) {
//       return const SizedBox.shrink();
//     }

//     return Consumer(
//       builder: (context, ref, child) {
//         final isConnected = _ff1Device?.topicId != null
//             ? ref.watch(ff1DeviceConnectedProvider)
//             : false;
//         final screenRotation = _deviceStatus?.screenRotation;

//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Display Orientation',
//               style: AppTypography.body(context).white,
//             ),
//             SizedBox(height: LayoutConstants.space4),
//             _displayOrientationPreview(
//               screenRotation != null
//                   ? ScreenOrientation.fromString(screenRotation)
//                   : null,
//             ),
//             SizedBox(height: LayoutConstants.space4),
//             PrimaryAsyncButton(
//               text: 'Rotate',
//               color: AppColor.white,
//               enabled: isConnected && _deviceStatus != null,
//               onTap: () async {
//                 // TODO: Implement rotate command using ff1WifiControlProvider or ff1BleSendCommandProvider
//                 _log.info('Rotate button tapped');
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _canvasSetting(BuildContext context) {
//     if (_ff1Device == null) {
//       return const SizedBox.shrink();
//     }

//     return Consumer(
//       builder: (context, ref, child) {
//         final isConnected = _ff1Device?.topicId != null
//             ? ref.watch(ff1DeviceConnectedProvider)
//             : false;

//         // TODO: Get current art framing setting from device status or player status
//         final artFramingIndex = 0; // Default to fit

//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Canvas',
//               style: AppTypography.body(context).white,
//             ),
//             SizedBox(height: LayoutConstants.space6 + LayoutConstants.space2),
//             // TODO: Implement SelectDeviceConfigView or create equivalent widget
//             // For now, show placeholder
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: AppColor.primaryBlack,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: [
//                   _canvasOption(
//                     context,
//                     'Fit',
//                     'assets/images/fit.png',
//                     isSelected: artFramingIndex == 0,
//                     isEnabled: isConnected,
//                     onTap: () {
//                       // TODO: Implement fit command
//                       _log.info('Fit selected');
//                     },
//                   ),
//                   _canvasOption(
//                     context,
//                     'Fill',
//                     'assets/images/fill.png',
//                     isSelected: artFramingIndex == 1,
//                     isEnabled: isConnected,
//                     onTap: () {
//                       // TODO: Implement fill command
//                       _log.info('Fill selected');
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }

//   Widget _canvasOption(
//     BuildContext context,
//     String title,
//     String imagePath, {
//     required bool isSelected,
//     required bool isEnabled,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: isEnabled ? onTap : null,
//       child: Opacity(
//         opacity: isEnabled ? 1.0 : 0.5,
//         child: Column(
//           children: [
//             Image.asset(
//               imagePath,
//               width: 100,
//               height: 100,
//             ),
//             const SizedBox(height: 8),
//             Text(
//               title,
//               style: AppTypography.body(context).white.copyWith(
//                     fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//                   ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   FutureOr<void> onWifiSelected(String ssid) {
//     if (_ff1Device == null) {
//       return;
//     }
//     _log.info('onWifiSelected: $ssid');

//     // TODO: Navigate to WiFi password screen using GoRouter
//     // For now, just log
//     _log.info('Navigate to WiFi password screen for device: ${_ff1Device!.deviceId}, SSID: $ssid');
//   }

//   Widget _deviceInfoItem(
//     BuildContext context, {
//     required String title,
//     required Widget child,
//   }) {
//     final theme = Theme.of(context);
//     return Row(
//       children: [
//         Expanded(
//           child: Text(
//             title,
//             style: AppTypography.body(context).grey,
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(child: child),
//       ],
//     );
//   }

//   Widget _deviceInfo(BuildContext context) {
//     final ff1Device = _ff1Device;
//     final installedVersion = _deviceStatus?.installedVersion;
//     final branchName = (ff1Device?.isReleaseBranch ?? true)
//         ? ''
//         : ' (${ff1Device?.branchName ?? ''})';
//     final deviceId = ff1Device?.deviceId ?? 'Unknown';
//     final connectedWifi = _deviceStatus?.connectedWifi;

//     final divider = Divider(
//       height: 16,
//       color: AppColor.auGreyBackground,
//       thickness: 1,
//     );

//     return Consumer(
//       builder: (context, ref, child) {
//         final isDeviceConnected = _ff1Device?.topicId != null
//             ? ref.watch(ff1DeviceConnectedProvider) && _deviceStatus != null
//             : false;
//         // TODO: Get sleeping state from player status if available
//         final isSleeping = false;
//         return Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Expanded(
//                   child: Text(
//                     'Device Information',
//                     style: AppTypography.body(context).white,
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: LayoutConstants.space4),

//             // Connection Status
//             Container(
//               padding: const EdgeInsets.all(15),
//               decoration: BoxDecoration(
//                 color: AppColor.primaryBlack,
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // connection status
//                   _deviceInfoItem(
//                     context,
//                     title: 'Connection Status:',
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Container(
//                           width: 12,
//                           height: 12,
//                           decoration: BoxDecoration(
//                             color: isDeviceConnected
//                                 ? isSleeping
//                                     ? Colors.grey
//                                     : Colors.green
//                                 : Colors.red,
//                             shape: BoxShape.circle,
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: Text(
//                             isDeviceConnected
//                                 ? isSleeping
//                                     ? 'Sleeping'
//                                     : 'Connected'
//                                 : 'Device not connected',
//                             style: AppTypography.body(context).white,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   divider,

//                   // Device Id

//                   _deviceInfoItem(
//                     context,
//                     title: 'Device Id:',
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Expanded(
//                           child: Text(
//                             deviceId,
//                             style: AppTypography.body(context).white.copyWith(
//                                   color: isDeviceConnected
//                                       ? AppColor.white
//                                       : AppColor.disabledColor,
//                                 ),
//                           ),
//                         ),
//                         _copyButton(
//                           context,
//                           deviceId,
//                         ),
//                       ],
//                     ),
//                   ),
//                   divider,
//                   // software version
//                   _deviceInfoItem(
//                     context,
//                     title: 'Software Version',
//                     child: RichText(
//                       text: TextSpan(
//                         style: AppTypography.body(context).white.copyWith(
//                               color: isDeviceConnected
//                                   ? AppColor.white
//                                   : AppColor.disabledColor,
//                             ),
//                         children: [
//                           TextSpan(
//                             text: (installedVersion ?? '-') + branchName,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   divider,

//                   // WiFi Network
//                   // Check if the device is connected to WiFi
//                   // If not connected, show "Not connected" message
//                   // If connected, show the connected WiFi name
//                   if (_deviceStatus != null) ...[
//                     _deviceInfoItem(
//                       context,
//                       title: 'Device Wifi Network',
//                       child: Text(
//                         connectedWifi ?? '-',
//                         style: AppTypography.body(context).white.copyWith(
//                               color: isDeviceConnected
//                                   ? AppColor.white
//                                   : AppColor.disabledColor,
//                             ),
//                       ),
//                     ),
//                     divider,
//                   ],
//                   ...[
//                     _deviceInfoItem(
//                       context,
//                       title: 'Screen Resolution',
//                       child: Builder(
//                         builder: (context) {
//                           // TODO: Get screen resolution from device status or metrics
//                           // For now, show placeholder
//                           return Text(
//                             '--',
//                             style: AppTypography.body(context).white.copyWith(
//                                   color: isDeviceConnected
//                                       ? AppColor.white
//                                       : AppColor.disabledColor,
//                                 ),
//                           );
//                         },
//                       ),
//                     ),
//                     divider,
//                   ],
//                   // refresh rate
//                   ...[
//                     _deviceInfoItem(
//                       context,
//                       title: 'Refresh Rate',
//                       child: Text(
//                         // TODO: Get refresh rate from device status or metrics
//                         '--',
//                         style: AppTypography.body(context).white.copyWith(
//                               color: isDeviceConnected
//                                   ? AppColor.white
//                                   : AppColor.disabledColor,
//                             ),
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//             if (isDeviceConnected && !isSleeping && _ff1Device != null) ...[
//               SizedBox(height: LayoutConstants.space4),
//               PrimaryAsyncButton(
//                 text:
//                     _isShowingQRCode ? 'Hide QR Code' : 'Show Pairing QR Code',
//                 color: AppColor.white,
//                 onTap: () async {
//                   // TODO: Implement show/hide QR code using project's providers
//                   _log.info('Show/Hide QR Code tapped');
//                   setState(() {
//                     _isShowingQRCode = !_isShowingQRCode;
//                   });
//                 },
//               ),
//             ],
//             SizedBox(height: LayoutConstants.space6 + LayoutConstants.space2),
//           ],
//         );
//       },
//     );
//   }

//   Widget _copyButton(BuildContext context, String deviceId) {
//     return GestureDetector(
//       onTap: () {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Device Id copied to clipboard'),
//             duration: const Duration(seconds: 2),
//           ),
//         );
//         unawaited(
//           Clipboard.setData(ClipboardData(text: deviceId)),
//         );
//       },
//       child: SvgPicture.asset(
//         'assets/images/copy.svg',
//         height: 16,
//         width: 16,
//         colorFilter: const ColorFilter.mode(
//           AppColor.white,
//           BlendMode.srcIn,
//         ),
//       ),
//     );
//   }

//   // Enable metrics streaming from the device
//   Future<void> _enableMetricsStreaming() async {
//     // TODO: Implement metrics streaming using project's providers
//     // For now, metrics are not available
//     _log.info('Metrics streaming not yet implemented');
//   }

//   // Disable metrics streaming from the device
//   Future<void> _stopMetricsStreaming() async {
//     try {
//       await _metricsStreamSubscription?.cancel();
//     } catch (e) {
//       _log.warning('Failed to disable metrics streaming: $e');
//     }
//   }

//   void _updateMetricsFromStream(dynamic metrics) {
//     if (!mounted) return;

//     // TODO: Re-implement when DeviceRealtimeMetrics is available
//     // For now, metrics streaming is not implemented
//     _log.info('Metrics update received but not yet implemented');

//     /* Original implementation - TODO: Re-enable when DeviceRealtimeMetrics is available
//     setState(() {
//       _latestMetrics = metrics;
//       // Add new performance data points
//       final timestamp = metrics.timestamp.toDouble();
//       if (metrics.cpu?.cpuUsage != null) {
//         final clampedValue = metrics.cpu!.cpuUsage!.clamp(0.0, 100.0);
//         _cpuPoints.add(FlSpot(timestamp, clampedValue));
//       }
//       if (metrics.memory?.memoryUsage != null) {
//         final clampedValue = metrics.memory!.memoryUsage!.clamp(0.0, 100.0);
//         _memoryPoints.add(FlSpot(timestamp, clampedValue));
//       }
//       if (metrics.gpu?.gpuUsage != null) {
//         final clampedValue = metrics.gpu!.gpuUsage!.clamp(0.0, 100.0);
//         _gpuPoints.add(FlSpot(timestamp, clampedValue));
//       }
//       if (metrics.cpu?.currentTemperature != null) {
//         final clampedValue = metrics.cpu!.currentTemperature!.clamp(0.0, 100.0);
//         _cpuTempPoints.add(FlSpot(timestamp, clampedValue));
//       }
//       if (metrics.gpu?.currentTemperature != null) {
//         final clampedValue = metrics.gpu!.currentTemperature!.clamp(0.0, 100.0);
//         _gpuTempPoints.add(FlSpot(timestamp, clampedValue));
//       }

//       if (metrics.screen?.fps != null) {
//         _fpsPoints.add(FlSpot(timestamp, metrics.screen!.fps!));
//       }

//       // Remove old points if we exceed the limit
//       while (_cpuPoints.length > _maxDataPoints) {
//         _cpuPoints.removeAt(0);
//         _memoryPoints.removeAt(0);
//         _gpuPoints.removeAt(0);
//         _cpuTempPoints.removeAt(0);
//         _gpuTempPoints.removeAt(0);
//       }

//       // sort points by timestamp
//       _cpuPoints.sort((FlSpot a, FlSpot b) => a.x.compareTo(b.x));
//       _memoryPoints.sort((FlSpot a, FlSpot b) => a.x.compareTo(b.x));
//       _gpuPoints.sort((FlSpot a, FlSpot b) => a.x.compareTo(b.x));
//       _cpuTempPoints.sort((FlSpot a, FlSpot b) => a.x.compareTo(b.x));
//       _gpuTempPoints.sort((FlSpot a, FlSpot b) => a.x.compareTo(b.x));
//       _fpsPoints.sort((FlSpot a, FlSpot b) => a.x.compareTo(b.x));
//     });
//     */
//   }

//   Widget _performanceMonitoring(BuildContext context) {
//     final theme = Theme.of(context);

//     // Define colors for each metric
//     const cpuColor = Colors.blue;
//     const memoryColor = Colors.green;
//     const gpuColor = Colors.red;

//     // Get the latest values from the points arrays
//     final cpuValue = _cpuPoints.isNotEmpty ? _cpuPoints.last.y : null;
//     final memoryValue = _memoryPoints.isNotEmpty ? _memoryPoints.last.y : null;
//     final gpuValue = _gpuPoints.isNotEmpty ? _gpuPoints.last.y : null;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Performance Monitoring',
//           style: AppTypography.body(context).white,
//         ),
//         const SizedBox(height: 16),

//         // Current values display
//         Container(
//           padding: const EdgeInsets.all(15),
//           decoration: BoxDecoration(
//             color: AppColor.primaryBlack,
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               _metricDisplay(context, 'CPU', cpuValue, '%', cpuColor),
//               _metricDisplay(context, 'Memory', memoryValue, '%', memoryColor),
//               _metricDisplay(context, 'GPU', gpuValue, '%', gpuColor),
//             ],
//           ),
//         ),

//         const SizedBox(height: 16),

//         // Performance chart
//         Container(
//           height: 200,
//           decoration: BoxDecoration(
//             color: AppColor.auGreyBackground,
//             borderRadius: BorderRadius.circular(10),
//           ),
//           padding: const EdgeInsets.all(16),
//           child: LineChart(
//             LineChartData(
//               minY: -20.0,
//               maxY: 120.0,
//               // Fixed range with buffer to prevent line clipping at edges
//               minX: (_cpuPoints.isEmpty ? 0.0 : _cpuPoints.first.x) - 20.0,
//               maxX: (_cpuPoints.isEmpty ? 0.0 : _cpuPoints.last.x) + 20.0,
//               clipData: const FlClipData.all(),
//               gridData: FlGridData(
//                 drawVerticalLine: false,
//                 horizontalInterval: 25,
//                 getDrawingHorizontalLine: (value) {
//                   return const FlLine(
//                     color: AppColor.feralFileMediumGrey,
//                     strokeWidth: 1,
//                   );
//                 },
//               ),
//               borderData: FlBorderData(show: false),
//               lineBarsData: [
//                 _createLineData(_cpuPoints, cpuColor, 'CPU'),
//                 _createLineData(_memoryPoints, memoryColor, 'Memory'),
//                 _createLineData(_gpuPoints, gpuColor, 'GPU'),
//               ],
//               titlesData: FlTitlesData(
//                 bottomTitles: const AxisTitles(),
//                 leftTitles: AxisTitles(
//                   sideTitles: SideTitles(
//                     showTitles: true,
//                     reservedSize: 40,
//                     interval: 25,
//                     getTitlesWidget: (value, meta) {
//                       // Hide min and max labels
//                       if (value == meta.min || value == meta.max) {
//                         return const SizedBox.shrink();
//                       }
//                       // Only show labels for values in the valid range (0-100)
//                       if (value < 0 || value > 100) {
//                         return const SizedBox.shrink();
//                       }
//                       return Text(
//                         '${value.toInt()}%',
//                         style: AppTypography.body(context).white,
//                       );
//                     },
//                   ),
//                 ),
//                 rightTitles: const AxisTitles(),
//                 topTitles: const AxisTitles(
//                   sideTitles: SideTitles(
//                     reservedSize: 30,
//                   ),
//                 ),
//               ),
//               lineTouchData: LineTouchData(
//                 touchCallback:
//                     (FlTouchEvent event, LineTouchResponse? touchResponse) {
//                   if (event is FlTapDownEvent) {
//                     HapticFeedback.lightImpact();
//                   }
//                 },
//                 touchTooltipData: LineTouchTooltipData(
//                   tooltipBorderRadius: BorderRadius.circular(8),
//                   tooltipPadding: const EdgeInsets.all(12),
//                   tooltipMargin: 8,
//                   getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
//                     // Sort spots by barIndex to ensure consistent order
//                     final sortedSpots = List<LineBarSpot>.from(touchedBarSpots)
//                       ..sort((a, b) => a.barIndex.compareTo(b.barIndex));

//                     // Get timestamp from the first spot (all spots have the same timestamp)
//                     final timestamp = sortedSpots.isNotEmpty
//                         ? '\nTime: ${_formatTimestamp(sortedSpots.first.x)}'
//                         : '';

//                     return sortedSpots.asMap().entries.map((entry) {
//                       final index = entry.key;
//                       final barSpot = entry.value;

//                       final metric = barSpot.barIndex == 0
//                           ? 'CPU'
//                           : barSpot.barIndex == 1
//                               ? 'Memory'
//                               : 'GPU';
//                       final color = barSpot.barIndex == 0
//                           ? cpuColor
//                           : barSpot.barIndex == 1
//                               ? memoryColor
//                               : gpuColor;

//                       return LineTooltipItem(
//                         '$metric: ${barSpot.y.toStringAsFixed(1)}%',
//                         TextStyle(
//                           color: color,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 12,
//                         ),
//                         children: index == sortedSpots.length - 1
//                             ? [
//                                 TextSpan(
//                                   text: timestamp,
//                                   style: const TextStyle(
//                                     color: Colors.white70,
//                                     fontWeight: FontWeight.normal,
//                                     fontSize: 10,
//                                   ),
//                                 ),
//                               ]
//                             : null,
//                       );
//                     }).toList();
//                   },
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _temperatureMonitoring(BuildContext context) {
//     final theme = Theme.of(context);

//     // Define colors for each metric
//     const cpuTempColor = Colors.blue;
//     const gpuTempColor = Colors.red;

//     // Get the latest values from the points arrays
//     final cpuTempValue =
//         _cpuTempPoints.isNotEmpty ? _cpuTempPoints.last.y : null;
//     final gpuTempValue =
//         _gpuTempPoints.isNotEmpty ? _gpuTempPoints.last.y : null;

//     // Convert to Fahrenheit if needed
//     final cpuTempDisplayValue = cpuTempValue;
//     final gpuTempDisplayValue = gpuTempValue;

//     // Temperature unit
//     const tempUnit = '°C';

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Temperature Monitoring',
//           style: AppTypography.body(context).white,
//         ),
//         const SizedBox(height: 16),

//         // Current values display
//         Container(
//           padding: const EdgeInsets.all(15),
//           decoration: BoxDecoration(
//             color: AppColor.primaryBlack,
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceAround,
//             children: [
//               _metricDisplay(
//                 context,
//                 'CPU Temp',
//                 cpuTempDisplayValue,
//                 tempUnit,
//                 cpuTempColor,
//               ),
//               _metricDisplay(
//                 context,
//                 'GPU Temp',
//                 gpuTempDisplayValue,
//                 tempUnit,
//                 gpuTempColor,
//               ),
//             ],
//           ),
//         ),

//         const SizedBox(height: 16),

//         // Temperature chart
//         Container(
//           height: 200,
//           decoration: BoxDecoration(
//             color: AppColor.auGreyBackground,
//             borderRadius: BorderRadius.circular(10),
//           ),
//           padding: const EdgeInsets.all(16),
//           child: LineChart(
//             LineChartData(
//               minY: -20.0,
//               maxY: 120.0,
//               // Fixed range with buffer to prevent line clipping at edges
//               minX: (_cpuTempPoints.isEmpty ? 0.0 : _cpuTempPoints.first.x) -
//                   20.0,
//               maxX:
//                   (_cpuTempPoints.isEmpty ? 0.0 : _cpuTempPoints.last.x) + 20.0,
//               clipData: const FlClipData.all(),
//               gridData: FlGridData(
//                 drawVerticalLine: false,
//                 horizontalInterval: 25,
//                 getDrawingHorizontalLine: (value) {
//                   return const FlLine(
//                     color: AppColor.feralFileMediumGrey,
//                     strokeWidth: 1,
//                   );
//                 },
//               ),
//               borderData: FlBorderData(show: false),
//               lineBarsData: [
//                 _createLineData(
//                   _cpuTempPoints,
//                   cpuTempColor,
//                   'CPU Temp',
//                 ),
//                 _createLineData(
//                   _gpuTempPoints,
//                   gpuTempColor,
//                   'GPU Temp',
//                 ),
//               ],
//               titlesData: FlTitlesData(
//                 bottomTitles: const AxisTitles(),
//                 leftTitles: AxisTitles(
//                   sideTitles: SideTitles(
//                     showTitles: true,
//                     reservedSize: 40,
//                     interval: 20, // ~20°C = 36°F interval
//                     getTitlesWidget: (value, meta) {
//                       // Hide min and max labels
//                       if (value == meta.min || value == meta.max) {
//                         return const SizedBox.shrink();
//                       }
//                       // Only show labels for reasonable temperature values (0-100°C)
//                       if (value < 0 || value > 100) {
//                         return const SizedBox.shrink();
//                       }
//                       return Text(
//                         '${value.toInt()}$tempUnit',
//                         style: AppTypography.body(context).white,
//                       );
//                     },
//                   ),
//                 ),
//                 rightTitles: const AxisTitles(),
//                 topTitles: const AxisTitles(),
//               ),
//               lineTouchData: LineTouchData(
//                 touchCallback:
//                     (FlTouchEvent event, LineTouchResponse? touchResponse) {
//                   if (event is FlTapDownEvent) {
//                     HapticFeedback.lightImpact();
//                   }
//                 },
//                 touchTooltipData: LineTouchTooltipData(
//                   tooltipBorderRadius: BorderRadius.circular(8),
//                   tooltipPadding: const EdgeInsets.all(12),
//                   tooltipMargin: 8,
//                   getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
//                     // Sort spots by barIndex to ensure consistent order
//                     final sortedSpots = List<LineBarSpot>.from(touchedBarSpots)
//                       ..sort((a, b) => a.barIndex.compareTo(b.barIndex));

//                     // Get timestamp from the first spot (all spots have the same timestamp)
//                     final timestamp = sortedSpots.isNotEmpty
//                         ? '\nTime: ${_formatTimestamp(sortedSpots.first.x)}'
//                         : '';

//                     return sortedSpots.asMap().entries.map((entry) {
//                       final index = entry.key;
//                       final barSpot = entry.value;

//                       final metric =
//                           barSpot.barIndex == 0 ? 'CPU Temp' : 'GPU Temp';
//                       final color =
//                           barSpot.barIndex == 0 ? cpuTempColor : gpuTempColor;
//                       final value = barSpot.y;

//                       return LineTooltipItem(
//                         '$metric: ${value.toStringAsFixed(1)}$tempUnit',
//                         TextStyle(
//                           color: color,
//                           fontWeight: FontWeight.bold,
//                           fontSize: 12,
//                         ),
//                         children: index == sortedSpots.length - 1
//                             ? [
//                                 TextSpan(
//                                   text: timestamp,
//                                   style: const TextStyle(
//                                     color: Colors.white70,
//                                     fontWeight: FontWeight.normal,
//                                     fontSize: 10,
//                                   ),
//                                 ),
//                               ]
//                             : null,
//                       );
//                     }).toList();
//                   },
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _metricDisplay(BuildContext context, String label, double? value, String unit, Color color) {
//     return Column(
//       children: [
//         Text(
//           label,
//           style: AppTypography.body(context).grey,
//         ),
//         SizedBox(height: LayoutConstants.space1),
//         Text(
//           '${value?.toStringAsFixed(1) ?? '--'} $unit',
//           style: AppTypography.body(context).white.copyWith(
//                 color: color,
//                 fontWeight: FontWeight.bold,
//               ),
//         ),
//       ],
//     );
//   }

//   LineChartBarData _createLineData(
//     List<FlSpot> points,
//     Color color,
//     String label,
//   ) {
//     // If no data points, return empty line with dotted style
//     if (points.isEmpty) {
//       return LineChartBarData(
//         spots: [
//           FlSpot(0, 0),
//           FlSpot(100, 0),
//         ],
//         dotData: const FlDotData(show: false),
//         color: color.withOpacity(0.3),
//         barWidth: 1,
//         isCurved: false,
//         dashArray: [5, 5],
//         // Create dotted line effect
//         belowBarData: BarAreaData(show: false),
//       );
//     }

//     return LineChartBarData(
//       spots: points,
//       dotData: const FlDotData(
//         show: false,
//       ),
//       color: color,
//       barWidth: 3,
//       isCurved: true,
//       preventCurveOverShooting: true,
//       preventCurveOvershootingThreshold: 0,
//       belowBarData: BarAreaData(
//         show: true,
//         color: color.withAlpha(40),
//       ),
//     );
//   }

//   // Helper method to format timestamp for tooltip display
//   String _formatTimestamp(double timestamp) {
//     final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
//     return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
//   }

//   void resetMetrics() {
//     setState(() {
//       _cpuPoints.clear();
//       _memoryPoints.clear();
//       _gpuPoints.clear();
//       _cpuTempPoints.clear();
//       _gpuTempPoints.clear();
//       _fpsPoints.clear();
//       _latestMetrics = null;
//     });
//   }

//   Widget _buildDeviceSwitcher(BuildContext context) {
//     // Get connected devices from Riverpod
//     final connectedDevicesAsync = ref.watch(connectedFF1DevicesProvider);

//     return connectedDevicesAsync.when(
//       data: (devices) {
//         // If there are less than 2 devices, don't show the switcher
//         if (devices.length < 2) {
//           return const SizedBox.shrink();
//         }

//         return PopupMenuButton<FF1Device>(
//           tooltip: 'Switch Device',
//           offset: const Offset(0, 40),
//           onSelected: (FF1Device device) async {
//             // Set as active device
//             await ref.read(
//               setActiveFF1BluetoothDeviceProvider(device.deviceId).future,
//             );
//             // Device will be reloaded automatically via ref.watch
//             // Reset metrics when switching devices
//             resetMetrics();
//           },
//           itemBuilder: (BuildContext context) {
//             return devices.map((FF1Device device) {
//               final isSelected = device.deviceId == _ff1Device?.deviceId;
//               return PopupMenuItem<FF1Device>(
//                 value: device,
//                 child: Row(
//                   children: [
//                     Icon(
//                       Icons.tv,
//                       color: isSelected
//                           ? AppColor.white
//                           : AppColor.white.withValues(alpha: 0.7),
//                       size: 20,
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Text(
//                         device.name,
//                         style: TextStyle(
//                           color: isSelected
//                               ? AppColor.white
//                               : AppColor.white.withValues(alpha: 0.9),
//                           fontWeight:
//                               isSelected ? FontWeight.bold : FontWeight.normal,
//                         ),
//                       ),
//                     ),
//                     if (isSelected) ...[
//                       const SizedBox(width: 8),
//                       const Icon(
//                         Icons.check_circle,
//                         color: AppColor.white,
//                         size: 16,
//                       ),
//                     ],
//                   ],
//                 ),
//               );
//             }).toList();
//           },
//           child: const Padding(
//             padding: EdgeInsets.all(8),
//             child: Icon(
//               Icons.devices,
//               color: AppColor.white,
//               size: 24,
//             ),
//           ),
//         );
//       },
//       loading: () => const SizedBox.shrink(),
//       error: (_, __) => const SizedBox.shrink(),
//     );
//   }

//   void _showOption(BuildContext context) {
//     if (_ff1Device == null) {
//       return;
//     }

//     // Use Consumer to watch device connection status
//     final isDeviceConnected = _ff1Device?.topicId != null
//         ? ref.read(ff1DeviceConnectedProvider) && _deviceStatus != null
//         : false;

//     final latestVersion = _deviceStatus?.latestVersion;
//     final hasUpdateAvailable = _deviceStatus?.latestVersion != null &&
//         _deviceStatus?.installedVersion != null &&
//         _deviceStatus!.latestVersion != _deviceStatus!.installedVersion;

//     // TODO: Get last update time from configuration service if available
//     final isLastUpdateLessThan15MinutesAgo = false;

//     // Show a simple dialog with options
//     showDialog<void>(
//       context: context,
//       builder: (dialogContext) => AlertDialog(
//         backgroundColor: AppColor.primaryBlack,
//         title: Text(
//           _ff1Device?.name ?? 'Device',
//           style: AppTypography.body(context).white,
//         ),
//         content: SingleChildScrollView(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               if (isDeviceConnected)
//                 ListTile(
//                   leading: const Icon(Icons.power_settings_new, color: AppColor.white),
//                   title: Text('Power Off', style: AppTypography.body(context).white),
//                   onTap: () {
//                     Navigator.pop(dialogContext);
//                     _onPowerOffSelected();
//                   },
//                 ),
//               if (isDeviceConnected)
//                 ListTile(
//                   leading: const Icon(Icons.restart_alt, color: AppColor.white),
//                   title: Text('Restart', style: AppTypography.body(context).white),
//                   onTap: () {
//                     Navigator.pop(dialogContext);
//                     _onRebootSelected();
//                   },
//                 ),
//               if (hasUpdateAvailable && isDeviceConnected)
//                 ListTile(
//                   leading: const Icon(Icons.system_update, color: AppColor.white),
//                   title: Text(
//                     isLastUpdateLessThan15MinutesAgo
//                         ? (latestVersion == null || latestVersion.isEmpty
//                             ? 'Updating...'
//                             : 'Updating to version $latestVersion...')
//                         : (latestVersion == null || latestVersion.isEmpty
//                             ? 'Update available'
//                             : 'Update to version $latestVersion'),
//                     style: AppTypography.body(context).white,
//                   ),
//                   enabled: !isLastUpdateLessThan15MinutesAgo,
//                   onTap: () {
//                     Navigator.pop(dialogContext);
//                     _onUpdateToLatestVersionSelected();
//                   },
//                 ),
//               ListTile(
//                 leading: const Icon(Icons.help, color: AppColor.white),
//                 title: Text('Send Log', style: AppTypography.body(context).white),
//                 onTap: () {
//                   Navigator.pop(dialogContext);
//                   _onSendLogSelected();
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.factory, color: AppColor.white),
//                 title: Text('Factory Reset', style: AppTypography.body(context).white),
//                 onTap: () {
//                   Navigator.pop(dialogContext);
//                   _onFactoryResetSelected();
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.book, color: AppColor.white),
//                 title: Text('FF1 Guide', style: AppTypography.body(context).white),
//                 onTap: () {
//                   Navigator.pop(dialogContext);
//                   _onViewDocumentationSelected();
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.wifi, color: AppColor.white),
//                 title: Text('Configure Wi-Fi', style: AppTypography.body(context).white),
//                 onTap: () {
//                   Navigator.pop(dialogContext);
//                   _onConfigureWiFiSelected();
//                 },
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//     /* Original code with OptionItem - TODO: Re-implement when OptionItem is available
//     final options = [
//       if (_isDeviceConnected)
//         OptionItem(
//           title: 'Power Off',
//           icon: const Icon(
//             Icons.power_settings_new,
//             size: 24,
//           ),
//           onTap: () {
//             _onPowerOffSelected();
//           },
//         ),
//       // reboot
//       if (isDeviceAlive)
//         OptionItem(
//           title: 'Restart',
//           icon: const Icon(
//             Icons.restart_alt,
//             size: 24,
//           ),
//           onTap: () {
//             _onRebootSelected();
//           },
//         ),
//       // Update to latest version
//       if (isDeviceAlive && hasUpdateAvailable)
//         OptionItem(
//           title: isLastUpdateLessThan15MinutesAgo
//               ? (latestVersion == null || latestVersion.isEmpty
//                   ? 'Updating...'
//                   : 'Updating to version $latestVersion...')
//               : (latestVersion == null || latestVersion.isEmpty
//                   ? 'Update available'
//                   : 'Update to version $latestVersion'),
//           icon: const Icon(
//             Icons.system_update,
//             size: 24,
//           ),
//           isEnable: !isLastUpdateLessThan15MinutesAgo,
//           onTap: () {
//             Navigator.pop(context); // Close drawer first
//             _onUpdateToLatestVersionSelected();
//           },
//         ),
//       OptionItem(
//         title: 'Send Log',
//         icon: Icon(AuIcon.help),
//         onTap: () async {
//           await _onSendLogSelected();
//         },
//       ),
//       OptionItem(
//         title: 'Factory Reset',
//         icon: Icon(Icons.factory),
//         onTap: () {
//           _onFactoryResetSelected();
//         },
//       ),
//       OptionItem(
//         title: 'FF1 Guide',
//         icon: Icon(Icons.book),
//         onTap: _onViewDocumentationSelected,
//       ),
//       OptionItem(
//         title: 'Configure Wi-Fi',
//         icon: Icon(Icons.wifi),
//         onTap: _onConfigureWiFiSelected,
//       ),
//       OptionItem.emptyOptionItem,
//     ];
//     unawaited(UIHelper.showDrawerAction(
//       context,
//       options: options,
//       title: _selectedDevice?.name ?? _ff1Device?.name ?? 'Device',
//     ));
//   }

//   Future<void> _onFactoryResetSelected() async {
//     final result = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: AppColor.primaryBlack,
//         title: Text(
//           'Factory Reset',
//           style: AppTypography.body(context).bold.white,
//         ),
//         content: Text(
//           'Are you sure you want to reset the device to factory settings? This will erase all data and cannot be undone.',
//           style: AppTypography.body(context).white,
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(false),
//             child: Text('Cancel', style: AppTypography.body(context).white),
//           ),
//           TextButton(
//             onPressed: () async {
//               try {
//                 if (_ff1Device == null) {
//                   Navigator.of(context).pop(false);
//                   return;
//                 }

//                 bool success = false;
//                 final device = _ff1Device!;

//                 // Try WiFi first if device has WiFi connection
//                 if (device.topicId != null && device.topicId!.isNotEmpty) {
//                   try {
//                     _log.info('[Factory Reset] Attempting via WiFi');
//                     // TODO: Implement factory reset via WiFi using ff1WifiSendCommandProvider
//                     // For now, fallback to BLE
//                     _log.warning('[Factory Reset] WiFi reset not yet implemented, using BLE');
//                   } catch (e) {
//                     _log.warning('[Factory Reset] WiFi error: $e, falling back to Bluetooth');
//                     unawaited(Sentry.captureEvent(SentryEvent(
//                       message: SentryMessage('Factory Reset WiFi error: $e, falling back to Bluetooth'),
//                       level: SentryLevel.warning,
//                       extra: {'device': device.deviceId},
//                     )));
//                   }
//                 }

//                 // Use Bluetooth if WiFi failed or not available
//                 if (!success) {
//                   _log.info('[Factory Reset] Attempting via Bluetooth');
//                   await ref.read(
//                     ff1BleSendCommandProvider(FF1BleCommandParams(
//                       device: device,
//                       command: FF1BleCommand.factoryReset,
//                       request: const FactoryResetRequest(),
//                       timeout: const Duration(seconds: 30),
//                     )).future,
//                   );
//                   success = true;
//                 }

//                 if (success) {
//                   // Remove device from storage
//                   await ref.read(
//                     forgetFF1DeviceProvider(device.deviceId).future,
//                   );
//                   Navigator.of(context).pop(true);
//                 }
//               } catch (e) {
//                 _log.severe('[Factory Reset] Failed: $e');
//                 unawaited(Sentry.captureEvent(SentryEvent(
//                   message: SentryMessage('Factory Reset Failed: $e'),
//                   level: SentryLevel.warning,
//                 )));
//                 Navigator.of(context).pop(false);
//               }
//             },
//             child: Text('Reset', style: AppTypography.body(context).white),
//           ),
//         ],
//       ),
//     );

//     // Handle dialog result
//     if (result == true) {
//       // TODO: Navigate to home using GoRouter
//       // Show success message
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Restoring Factory Defaults. Please keep the FF1 powered on.'),
//             duration: const Duration(seconds: 5),
//           ),
//         );
//       }
//     } else if (result == false) {
//       // User cancelled, no action needed
//     }
//   }

//   void _onPowerOffSelected() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: AppColor.primaryBlack,
//         title: Text(
//           'Power Off',
//           style: AppTypography.body(context).bold.white,
//         ),
//         content: Text(
//           'Are you sure you want to power off the device?',
//           style: AppTypography.body(context).white,
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel', style: AppTypography.body(context).white),
//           ),
//           TextButton(
//             onPressed: () async {
//               if (_ff1Device != null) {
//                 // TODO: Implement power off command using ff1BleSendCommandProvider or WiFi
//                 _log.info('Power off requested for device: ${_ff1Device!.deviceId}');
//                 Navigator.of(context).pop();
//               }
//             },
//             child: Text('OK', style: AppTypography.body(context).white),
//           ),
//         ],
//       ),
//     );
//   }

//   void _onRebootSelected() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: AppColor.primaryBlack,
//         title: Text(
//           'Restart',
//           style: AppTypography.body(context).bold.white,
//         ),
//         content: Text(
//           'Are you sure you want to restart the device?',
//           style: AppTypography.body(context).white,
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: Text('Cancel', style: AppTypography.body(context).white),
//           ),
//           TextButton(
//             onPressed: () async {
//               if (_ff1Device != null) {
//                 // TODO: Implement restart command using ff1BleSendCommandProvider or WiFi
//                 _log.info('Restart requested for device: ${_ff1Device!.deviceId}');
//                 Navigator.of(context).pop();
//               }
//             },
//             child: Text('OK', style: AppTypography.body(context).white),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _onSendLogSelected() async {
//     try {
//       if (_ff1Device == null) {
//         return;
//       }
//       final device = _ff1Device!;
//       bool success = false;

//       // Try WiFi first if device has WiFi connection
//       if (device.topicId != null && device.topicId!.isNotEmpty) {
//         try {
//           _log.info('[Send Log] Attempting via WiFi');
//           // TODO: Implement send log via WiFi using ff1WifiSendCommandProvider
//           _log.warning('[Send Log] WiFi send log not yet implemented, using BLE');
//         } catch (e) {
//           _log.warning('[Send Log] WiFi error: $e, falling back to Bluetooth');
//           unawaited(Sentry.captureEvent(SentryEvent(
//             message: SentryMessage('Send Log WiFi error: $e, falling back to Bluetooth'),
//             level: SentryLevel.warning,
//             extra: {'device': device.deviceId},
//           )));
//         }
//       }

//       // Fallback to Bluetooth if WiFi failed or not available
//       if (!success) {
//         _log.info('[Send Log] Attempting via Bluetooth');
//         // TODO: Get userId, title, apiKey from configuration
//         // For now, use placeholder values
//         await ref.read(
//           ff1BleSendCommandProvider(FF1BleCommandParams(
//             device: device,
//             command: FF1BleCommand.sendLog,
//             request: SendLogRequest(
//               userId: 'user', // TODO: Get from config
//               title: 'Device Log', // TODO: Get from config
//               apiKey: '', // TODO: Get from config
//             ),
//             timeout: const Duration(seconds: 30),
//           )).future,
//         );
//         success = true;
//       }

//       if (success && mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Your log has been sent to support. Thank you for your help!'),
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       } else if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('The FF1 failed to send log to support.'),
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     } catch (e) {
//       _log.severe('Error sending log: $e');
//       unawaited(Sentry.captureEvent(SentryEvent(
//         message: SentryMessage('Failed to send log to support'),
//         level: SentryLevel.warning,
//         throwable: e,
//       )));
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to send log to support. Please try again.'),
//             duration: const Duration(seconds: 3),
//           ),
//         );
//       }
//     }
//   }

//   void _onViewDocumentationSelected() {
//     // TODO: Get URL from configuration service
//     final url = 'https://docs.feralfile.com/ff1?from=app';
//     final uri = Uri.parse(url);
//     // TODO: Use url_launcher or project's URL opening mechanism
//     _log.info('Opening documentation: $url');
//   }

//   void _onConfigureWiFiSelected() {
//     if (_ff1Device == null) {
//       return;
//     }

//     // TODO: Navigate to WiFi scan screen using GoRouter
//     // For now, just log
//     _log.info('Navigate to WiFi configuration for device: ${_ff1Device!.deviceId}');
//   }

//   Future<void> _onUpdateToLatestVersionSelected() async {
//     if (_deviceStatus == null) {
//       return;
//     }

//     // TODO: Implement firmware update dialog using project's navigation system
//     _log.info('Firmware update requested: ${_deviceStatus!.installedVersion} -> ${_deviceStatus!.latestVersion}');

//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Firmware update feature not yet implemented'),
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     }
//   }
// }

// // Widget wrapper to prevent parent scroll when interacting with WebView
// // This solution uses a combination of approaches:
// // 1. NotificationListener to prevent scroll notifications from propagating
// // 2. GestureDetector to detect vertical drags and prevent parent scroll
// class _WebViewScrollWrapper extends StatefulWidget {
//   const _WebViewScrollWrapper({required this.child});

//   final Widget child;

//   @override
//   State<_WebViewScrollWrapper> createState() => _WebViewScrollWrapperState();
// }

// class _WebViewScrollWrapperState extends State<_WebViewScrollWrapper> {
//   bool _isInteracting = false;

//   @override
//   Widget build(BuildContext context) {
//     return NotificationListener<ScrollNotification>(
//       onNotification: (notification) {
//         // Prevent parent scroll when interacting with WebView
//         if (_isInteracting) {
//           return true;
//         }
//         return false;
//       },
//       child: GestureDetector(
//         // Detect when user starts dragging in WebView area
//         onVerticalDragStart: (_) {
//           setState(() {
//             _isInteracting = true;
//           });
//         },
//         onVerticalDragEnd: (_) {
//           // Reset after a delay to allow WebView to handle the gesture
//           Future.delayed(const Duration(milliseconds: 100), () {
//             if (mounted) {
//               setState(() {
//                 _isInteracting = false;
//               });
//             }
//           });
//         },
//         onVerticalDragCancel: () {
//           if (mounted) {
//             setState(() {
//               _isInteracting = false;
//             });
//           }
//         },
//         // Allow gestures to pass through to WebView
//         behavior: HitTestBehavior.translucent,
//         child: widget.child,
//       ),
//     );
//   }
// }
