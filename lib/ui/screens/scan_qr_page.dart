import 'dart:async';

import 'package:app/app/providers/scan_qr_provider.dart';
import 'package:app/app/route_observer.dart';
import 'package:app/app/routing/deeplink_handler.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/scan_qr_camera_session.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Payload for the global QR scanner page.
class ScanQrPagePayload {
  /// Constructor
  const ScanQrPagePayload({
    this.mode = ScanQrMode.global,
  });

  /// The mode of the scanner.
  final ScanQrMode mode;
}

/// Global reusable QR scanner page.
class ScanQrPage extends ConsumerStatefulWidget {
  /// Creates the scan QR page.
  const ScanQrPage({
    required this.payload,
    super.key,
  });

  /// Payload carrying scanner mode (e.g. global vs address).
  final ScanQrPagePayload payload;

  @override
  ConsumerState<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends ConsumerState<ScanQrPage>
    with RouteAware, WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
  );
  late final ScanQrCameraSession _cameraSession;
  Timer? _clearErrorTimer;

  @override
  void initState() {
    super.initState();
    _cameraSession = ScanQrCameraSession(
      startCamera: _controller.start,
      stopCamera: _controller.stop,
    );
    WidgetsBinding.instance.addObserver(this);
    unawaited(_resumeCamera());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPushNext() {
    unawaited(_pauseCamera());
    super.didPushNext();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    unawaited(_resumeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumeCamera());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      unawaited(_pauseCamera());
    }
  }

  Future<void> _pauseCamera() async {
    await _cameraSession.pause();
  }

  Future<void> _resumeCamera() async {
    await _cameraSession.resume();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (capture.barcodes.isEmpty) {
      return;
    }

    final code = capture.barcodes.first.rawValue;
    final action = ref
        .read(scanQrProvider.notifier)
        .processScan(
          rawValue: code,
          mode: widget.payload.mode,
        );

    switch (action.type) {
      case ScanQrActionType.ignore:
        return;
      case ScanQrActionType.showError:
        _clearErrorTimer?.cancel();
        _clearErrorTimer = Timer(const Duration(seconds: 4), () {
          ref.read(scanQrProvider.notifier).clearError();
        });
        return;
      case ScanQrActionType.returnScannedValue:
        await _pauseCamera();
        if (mounted) {
          context.pop(action.value);
        }
        return;
      case ScanQrActionType.handleDeeplink:
        await _pauseCamera();
        await ref
            .read(deeplinkHandlerProvider)
            .handleRawLink(
              action.value,
              source: DeeplinkSource.scan,
              onFinished: () {
                ref.read(scanQrProvider.notifier).markReady();
                if (mounted) {
                  context.pop();
                }
              },
            );
        return;
    }
  }

  @override
  void dispose() {
    _clearErrorTimer?.cancel();
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cameraSession.dispose());
    unawaited(_controller.dispose());
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    final topPadding = MediaQuery.viewPaddingOf(context).top;

    return Padding(
      padding: EdgeInsets.only(
        top: topPadding,
        left: LayoutConstants.space5,
        right: LayoutConstants.space2,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Scan',
              style: AppTypography.body(context).white,
            ),
          ),
          IconButton(
            onPressed: () {
              if (context.mounted) {
                context.pop();
              }
            },
            icon: SvgPicture.asset(
              'assets/images/close.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                AppColor.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Instruction banner at bottom (SplitBanner-style from sample).
  Widget _buildInstructionBanner(BuildContext context) {
    final state = ref.watch(scanQrProvider);
    const instructionTitle = 'Scan QR code in order to';
    final instructionBody = state.isScanDataError
        ? 'Invalid QR code for this flow. Try another code.'
        : 'Scan a Feral File deeplink or wallet address';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: LayoutConstants.space18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(LayoutConstants.space2),
        ),
        child: Padding(
          padding: EdgeInsets.all(LayoutConstants.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    'assets/images/scan.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      AppColor.white,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(width: LayoutConstants.space5),
                  Expanded(
                    child: Text(
                      instructionTitle,
                      style: AppTypography.body(context).white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: LayoutConstants.space2),
              Text(
                instructionBody,
                style: state.isScanDataError
                    ? AppTypography.body(context).red
                    : AppTypography.body(context).grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanQrProvider);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: AppColor.primaryBlack,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: 0,
          leadingWidth: 0,
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: MobileScanner(
                controller: _controller,
                onDetect: _handleBarcode,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(context),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildInstructionBanner(context),
              ),
            ),
            if (state.isLoading)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: CupertinoActivityIndicator(
                      color: theme.colorScheme.primary,
                      radius: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
