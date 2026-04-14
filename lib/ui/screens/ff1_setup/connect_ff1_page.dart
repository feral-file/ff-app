import 'dart:async';

import 'package:app/app/ff1_setup/ff1_setup_effect.dart';
import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/app/providers/connect_ff1_providers.dart';
import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/scan_wifi_network_screen.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gif_view/gif_view.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';

/// BLE chrome phases — derived from [connectFF1Provider] only. Portal / Wi‑Fi
/// routing uses [ff1SetupOrchestratorProvider] separately.
enum _BleConnectUiPhase {
  connecting,
  stillConnecting,
  bluetoothOff,
  error,
  success,
}

final _log = Logger('ConnectFF1Page');

/// Payload for the connect FF1 page
class ConnectFF1PagePayload {
  /// Constructor
  ConnectFF1PagePayload({
    required this.device,
    required this.ff1DeviceInfo,
  });

  /// Bluetooth device to connect to (required).
  final BluetoothDevice device;

  /// Optional device info parsed from deeplink or other source.
  /// When non-null, used to skip get_info command and provide metadata early.
  final FF1DeviceInfo? ff1DeviceInfo;
}

/// Connect FF1 page
class ConnectFF1Page extends ConsumerStatefulWidget {
  /// Constructor
  const ConnectFF1Page({
    required this.payload,
    super.key,
  });

  /// Payload for the page
  final ConnectFF1PagePayload payload;

  @override
  ConsumerState<ConnectFF1Page> createState() => _ConnectFF1PageState();
}

class _ConnectFF1PageState extends ConsumerState<ConnectFF1Page> {
  DateTime? _startTime;
  FF1SetupOrchestratorNotifier? _setupOrchestrator;
  ConnectFF1Notifier? _connectFF1Notifier;
  ProviderSubscription<FF1SetupState>? _setupSub;
  bool _guidedCompletionPending = false;
  bool _successExitPending = false;
  bool _successExitShowsPortal = false;
  bool _portalReadyCompletionPending = false;
  bool _portalReadySessionCompleted = false;
  FF1Device? _portalReadyDevice;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();

    _setupSub = ref.listenManual<FF1SetupState>(
      ff1SetupOrchestratorProvider,
      (previous, next) {
        final effectId = next.effectId;
        final effect = next.effect;
        if (previous?.effectId != effectId && effect != null) {
          // Bind success handling to the session that existed when the effect
          // was emitted; async handlers must not re-read
          // [hasGuidedSetupSession] after [cancelSession] may have cleared the
          // guided session.
          final sessionIdAtEmission = next.activeSession?.id;
          final orchestrator = ref.read(ff1SetupOrchestratorProvider.notifier);
          unawaited(() async {
            final didHandle = await _handleOrchestratorEffect(
              effect,
              sessionIdAtEmission: sessionIdAtEmission,
            );
            if (didHandle) {
              orchestrator.ackEffect(effectId: effectId);
            }
          }());
        }
      },
    );

    _setupOrchestrator = ref.read(ff1SetupOrchestratorProvider.notifier);
    _connectFF1Notifier = ref.read(connectFF1Provider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_startConnectFlow());
    });
  }

  @override
  void dispose() {
    _cancelBleConnectAttempt();
    _setupSub?.close();
    super.dispose();
  }

  /// Clear page-local success latches before a new connect attempt starts.
  ///
  /// The orchestrator owns durable setup/session state, but this page keeps a
  /// few UI-only latches to avoid flashing between success and route
  /// replacement. Those latches must be reset on retry so a fresh attempt does
  /// not inherit portal-ready chrome or a stale verified device.
  void _resetAttemptUiState() {
    _guidedCompletionPending = false;
    _successExitPending = false;
    _successExitShowsPortal = false;
    _portalReadyCompletionPending = false;
    _portalReadySessionCompleted = false;
    _portalReadyDevice = null;
  }

  /// Portal-all-set UI is only valid after the live connect flow verifies the
  /// device. Deeplink metadata can be stale, so it must not mask BLE errors or
  /// skip setup completion on its own.
  bool _shouldShowPortalIsSet(FF1SetupState setupState) {
    return (_successExitPending && _successExitShowsPortal) ||
        _portalReadyCompletionPending ||
        _portalReadySessionCompleted ||
        setupState.connected?.portalIsSet == true;
  }

  _BleConnectUiPhase _bleConnectionStatus(AsyncValue<ConnectFF1State> connect) {
    if (_successExitPending) {
      return _BleConnectUiPhase.success;
    }
    return connect.when(
      data: (s) => switch (s) {
        ConnectFF1Initial() => _BleConnectUiPhase.connecting,
        ConnectFF1Connecting() => _BleConnectUiPhase.connecting,
        ConnectFF1StillConnecting() => _BleConnectUiPhase.stillConnecting,
        ConnectFF1BluetoothOff() => _BleConnectUiPhase.bluetoothOff,
        ConnectFF1Cancelled() => _BleConnectUiPhase.connecting,
        ConnectFF1Error() => _BleConnectUiPhase.error,
        ConnectFF1Connected() => _BleConnectUiPhase.success,
      },
      error: (_, _) => _BleConnectUiPhase.error,
      loading: () => _BleConnectUiPhase.connecting,
    );
  }

  Future<bool> _handleOrchestratorEffect(
    FF1SetupEffect effect, {
    required String? sessionIdAtEmission,
  }) async {
    switch (effect) {
      case FF1SetupInternetReady(:final connected):
        _recordDuration(success: true);
        if (sessionIdAtEmission != null) {
          if (connected.portalIsSet) {
            unawaited(
              _completeGuidedPortalSession(
                connected.ff1device,
                sessionIdAtEmission: sessionIdAtEmission,
                navigateAfterCompletion: false,
                shouldNavigate: !connected.portalIsSet,
              ),
            );
          } else {
            unawaited(
              _completeGuidedDirectSuccess(
                connected.ff1device,
                sessionIdAtEmission: sessionIdAtEmission,
                shouldNavigate: !connected.portalIsSet,
              ),
            );
          }
          return true;
        }
        // Standalone connect: internet-ready must persist onboarding before
        // leaving setup. If the portal is already configured, keep the portal
        // screen until the user taps Go to Settings.
        if (connected.portalIsSet) {
          return true;
        }
        final orchestrator = ref.read(ff1SetupOrchestratorProvider.notifier);
        if (!orchestrator.matchesSessionForEffect(null)) {
          return true;
        }
        unawaited(
          _completeDirectSuccessExit(
            device: connected.ff1device,
            preservePortalUi: false,
          ),
        );
        return true;
      case FF1SetupNeedsWiFi(:final device):
        if (!context.mounted) return false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.replace(
            Routes.scanWifiNetworks,
            extra: ScanWifiNetworkPagePayload(device: device),
          );
        });
        return true;
      case FF1SetupNavigate():
        return false;
      case FF1SetupPop():
        return false;
      case FF1SetupDeviceUpdating():
        if (!context.mounted) return false;
        context.go(Routes.ff1Updating);
        return true;
      case FF1SetupShowError(
        :final title,
        :final message,
        :final showSupportCta,
      ):
        _recordDuration(success: false);
        if (!context.mounted) return false;
        final supportEmailService = showSupportCta
            ? ref.read(supportEmailServiceProvider)
            : null;
        await UIHelper.showInfoDialog(
          context,
          title,
          message,
          closeButton: showSupportCta ? 'Contact support' : '',
          onClose: showSupportCta
              ? (nextContext) {
                  return UIHelper.showCustomerSupport(
                    nextContext,
                    supportEmailService: supportEmailService!,
                  );
                }
              : null,
        );
        return true;
      case FF1SetupEnterWifiPassword():
        return false;
    }
  }

  Future<void> _startConnectFlow() async {
    _startTime = DateTime.now();
    _log.info('[ConnectFF1Page] Start connecting to FF1');
    _resetAttemptUiState();
    final notifier = _setupOrchestrator;
    if (notifier == null) {
      return;
    }
    await notifier.startConnect(
      device: widget.payload.device,
      deeplinkInfo: widget.payload.ff1DeviceInfo,
    );
  }

  /// This page owns only the active BLE connect attempt. Guided setup session
  /// lifetime is managed by setup entry/exit routes, so page-level cleanup
  /// must not clear the durable setup session.
  void _cancelBleConnectAttempt() {
    _connectFF1Notifier?.cancelConnection();
  }

  void _recordDuration({required bool success}) {
    if (_startTime == null) {
      return;
    }
    final duration = DateTime.now().difference(_startTime!);
    final ms = duration.inMilliseconds;
    String bucket;
    if (duration.inSeconds < 5) {
      bucket = '<5s';
    } else if (duration.inSeconds <= 10) {
      bucket = '5-10s';
    } else {
      bucket = '>10s';
    }
    _log.info(
      '[ConnectFF1Page] Connection ${success ? "success" : "failure"} '
      'duration=${duration.inSeconds}s (${ms}ms), bucket=$bucket',
    );
  }

  Future<void> _onCancel() async {
    if (_guidedCompletionPending || _successExitPending) {
      return;
    }
    _log.info('[ConnectFF1Page] Cancel pressed, cancelling connection');
    final orchestrator = ref.read(ff1SetupOrchestratorProvider.notifier);
    if (orchestrator.hasGuidedSetupSession) {
      await orchestrator.cancelSession(FF1SetupSessionCancelReason.userAborted);
    } else {
      _cancelBleConnectAttempt();
      try {
        await widget.payload.device.disconnect();
      } on Object catch (e) {
        _log.info('[ConnectFF1Page] Error while disconnecting: $e');
      }
    }

    if (!mounted) {
      return;
    }
    context.pop();
  }

  Future<void> _exitConnectSuccess({
    required bool tearDownBeforeNavigate,
    required bool preservePortalUi,
  }) async {
    if (_guidedCompletionPending || _successExitPending || !mounted) {
      return;
    }

    setState(() {
      _successExitPending = true;
      _successExitShowsPortal = preservePortalUi;
    });

    if (tearDownBeforeNavigate) {
      await ref
          .read(ff1SetupOrchestratorProvider.notifier)
          .tearDownAfterSetupComplete();
      if (!mounted) {
        return;
      }
    }

    // Keep this route's success chrome latched until replacement disposes the
    // page. Without that, teardown resets connect state first and can flash
    // back to "Connecting" before device configuration appears.
    unawaited(GoRouter.of(context).replace<void>(Routes.deviceConfiguration));
  }

  Future<void> _completeDirectSuccessExit({
    required FF1Device device,
    required bool preservePortalUi,
    bool bypassPendingGuard = false,
  }) async {
    if (!ref
        .read(ff1SetupOrchestratorProvider.notifier)
        .matchesSessionForEffect(null)) {
      return;
    }
    if (!bypassPendingGuard &&
        (_guidedCompletionPending || _successExitPending || !mounted)) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() {
      // If the guided path fell back here, clear the guided latch so the page
      // can actually finish. The caller already proved the guided session is
      // gone, so keeping the old guard would dead-end this recovery path.
      _guidedCompletionPending = false;
      _successExitPending = true;
      _successExitShowsPortal = preservePortalUi;
    });

    try {
      await ref
          .read(ff1SetupOrchestratorProvider.notifier)
          .completeInternetReadySetup(device, shouldNavigate: false);
    } on Object catch (e, st) {
      _log.warning(
        '[ConnectFF1Page] Direct success completion failed',
        e,
        st,
      );
      if (mounted) {
        setState(() {
          _successExitPending = false;
          _successExitShowsPortal = false;
        });
      }
      if (!mounted) {
        return;
      }
      final dialogContext = context;
      if (!dialogContext.mounted) {
        return;
      }
      await UIHelper.showInfoDialog(
        dialogContext,
        'Setup could not finish',
        'We couldn’t finish saving your FF1 setup. Please try again.',
        closeButton: 'Close',
      );
      return;
    }

    if (!mounted) {
      return;
    }
    unawaited(GoRouter.of(context).replace<void>(Routes.deviceConfiguration));
  }

  Future<void> _completeGuidedDirectSuccess(
    FF1Device device, {
    required String sessionIdAtEmission,
    required bool shouldNavigate,
  }) async {
    if (!ref
        .read(ff1SetupOrchestratorProvider.notifier)
        .matchesSessionForEffect(sessionIdAtEmission)) {
      return;
    }
    if (_guidedCompletionPending || _successExitPending || !mounted) {
      return;
    }

    // Guided BLE success resets orchestrator/connect state before navigation.
    // Callers pass `shouldNavigate: !connected.portalIsSet`: when false,
    // [completeSession] leaves routing to this page (`replace` fallback below);
    // when true, the orchestrator runs `GoRouter.go` to device configuration.
    // Latch success chrome locally first so the page cannot flash back to the
    // default "Connecting" copy for a frame.
    setState(() {
      _guidedCompletionPending = true;
      _successExitPending = true;
      _successExitShowsPortal = false;
    });

    try {
      final completed = await ref
          .read(ff1SetupOrchestratorProvider.notifier)
          .completeSession(device, shouldNavigate: shouldNavigate);
      if (!completed) {
        if (mounted) {
          setState(() {
            _guidedCompletionPending = false;
            _successExitPending = false;
            _successExitShowsPortal = false;
          });
        }
        return;
      }
    } on Object catch (e, st) {
      _log.warning(
        '[ConnectFF1Page] Guided session completion failed',
        e,
        st,
      );
      if (mounted) {
        setState(() {
          _guidedCompletionPending = false;
          _successExitPending = false;
          _successExitShowsPortal = false;
        });
      }
      if (!mounted) {
        return;
      }
      final dialogContext = context;
      if (!dialogContext.mounted) {
        return;
      }
      await UIHelper.showInfoDialog(
        dialogContext,
        'Setup could not finish',
        'We couldn’t finish saving your FF1 setup. Please try again.',
        closeButton: 'Close',
      );
      if (!mounted) {
        return;
      }
      await ref
          .read(ff1SetupOrchestratorProvider.notifier)
          .cancelSession(FF1SetupSessionCancelReason.userAborted);
      if (!mounted) {
        return;
      }
      GoRouter.of(context).pop();
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _guidedCompletionPending = false;
    });
    if (!shouldNavigate) {
      unawaited(GoRouter.of(context).replace<void>(Routes.deviceConfiguration));
    }
  }

  Future<void> _completeGuidedPortalSession(
    FF1Device device, {
    required String sessionIdAtEmission,
    required bool navigateAfterCompletion,
    required bool shouldNavigate,
  }) async {
    if (!ref
        .read(ff1SetupOrchestratorProvider.notifier)
        .matchesSessionForEffect(sessionIdAtEmission)) {
      return;
    }
    if (_portalReadyCompletionPending || _successExitPending || !mounted) {
      return;
    }

    setState(() {
      _guidedCompletionPending = true;
      _portalReadyCompletionPending = true;
      _portalReadyDevice = device;
    });

    try {
      final completed = await ref
          .read(ff1SetupOrchestratorProvider.notifier)
          .completeSession(device, shouldNavigate: shouldNavigate);
      if (!completed) {
        if (mounted) {
          setState(() {
            _guidedCompletionPending = false;
            _portalReadyCompletionPending = false;
            _portalReadySessionCompleted = false;
          });
        }
        return;
      }
    } on Object catch (e, st) {
      _log.warning(
        '[ConnectFF1Page] Guided portal completion failed',
        e,
        st,
      );
      if (mounted) {
        setState(() {
          _guidedCompletionPending = false;
          _portalReadyCompletionPending = false;
          _portalReadySessionCompleted = false;
        });
      }
      if (!mounted) {
        return;
      }
      final dialogContext = context;
      if (!dialogContext.mounted) {
        return;
      }
      await UIHelper.showInfoDialog(
        dialogContext,
        'Setup could not finish',
        'We couldn’t finish saving your FF1 setup. Please try again.',
        closeButton: 'Close',
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _guidedCompletionPending = false;
      _portalReadyCompletionPending = false;
      _portalReadySessionCompleted = true;
      _portalReadyDevice = device;
    });
    if (navigateAfterCompletion) {
      await _exitConnectSuccess(
        tearDownBeforeNavigate: false,
        preservePortalUi: true,
      );
    }
  }

  Future<void> _onPortalGoToSettings() async {
    final setup = ref.read(ff1SetupOrchestratorProvider);
    final device = setup.connected?.ff1device ?? _portalReadyDevice;
    if (device == null) {
      _log.warning(
        '[ConnectFF1Page] Ignoring portal settings tap without verified '
        'ConnectFF1Connected state',
      );
      return;
    }
    if (_portalReadyCompletionPending) {
      return;
    }
    final isGuidedPortalFlow =
        ref.read(ff1SetupOrchestratorProvider.notifier).hasGuidedSetupSession ||
        _portalReadyDevice != null;
    if (isGuidedPortalFlow && !_portalReadySessionCompleted) {
      final sessionId = ref
          .read(ff1SetupOrchestratorProvider)
          .activeSession
          ?.id;
      if (sessionId == null) {
        return;
      }
      await _completeGuidedPortalSession(
        device,
        sessionIdAtEmission: sessionId,
        navigateAfterCompletion: true,
        shouldNavigate: false,
      );
      return;
    }
    if (!isGuidedPortalFlow) {
      await _completeDirectSuccessExit(
        device: device,
        preservePortalUi: true,
      );
      return;
    }
    await _exitConnectSuccess(
      tearDownBeforeNavigate: false,
      preservePortalUi: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final setupState = ref.watch(ff1SetupOrchestratorProvider);
    final connectAsync = ref.watch(connectFF1Provider);
    _log.info('UI state -> $setupState connect=$connectAsync');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_onCancel());
        }
      },
      child: Scaffold(
        appBar: SetupAppBar(
          withDivider: false,
          onBack: (_guidedCompletionPending || _successExitPending)
              ? () {}
              : () {
                  unawaited(_onCancel());
                },
        ),
        backgroundColor: AppColor.auGreyBackground,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: LayoutConstants.space4,
              horizontal: LayoutConstants.setupPageHorizontal,
            ),
            child: _buildMainColumn(context, ref, setupState, connectAsync),
          ),
        ),
      ),
    );
  }

  Widget _buildMainColumn(
    BuildContext context,
    WidgetRef ref,
    FF1SetupState setupState,
    AsyncValue<ConnectFF1State> connectAsync,
  ) {
    if (_shouldShowPortalIsSet(setupState)) {
      return _portalIsSetView(context);
    }

    final ble = _bleConnectionStatus(connectAsync);
    return switch (ble) {
      _BleConnectUiPhase.bluetoothOff => _bluetoothNotAvailableView(context),
      _BleConnectUiPhase.error => _bleErrorView(context),
      _BleConnectUiPhase.connecting ||
      _BleConnectUiPhase.stillConnecting ||
      _BleConnectUiPhase.success => _bleConnectingOrSuccessView(context, ble),
    };
  }

  Widget _portalIsSetView(BuildContext context) {
    final canGoToSettings = !_portalReadyCompletionPending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/ff_logo.png',
                width: 139,
                height: 92.67,
              ),
              const SizedBox(height: 85),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The FF1 is All Set',
                      style: AppTypography.h2(context).white,
                    ),
                    SizedBox(height: LayoutConstants.space5),
                    Text(
                      'Your FF1 is already set up and connected. You can head '
                      'to settings to make changes or check the status.',
                      style: AppTypography.body(context).white,
                    ),
                    SizedBox(height: LayoutConstants.space5),
                    PrimaryButton(
                      onTap: _onPortalGoToSettings,
                      enabled: canGoToSettings,
                      isProcessing: _portalReadyCompletionPending,
                      text: 'Go to Settings',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bleErrorView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.error,
                size: LayoutConstants.iconSizeLarge * 2,
                color: PrimitivesTokens.colorsLightBlue,
              ),
              SizedBox(height: LayoutConstants.space4),
              Align(
                child: Column(
                  children: [
                    Text(
                      'We couldn’t connect to FF1',
                      style: AppTypography.h2(context).white,
                    ),
                    SizedBox(height: LayoutConstants.space5),
                    Text(
                      'A few things to check:\n'
                      '• Make sure your FF1 is powered on.\n'
                      '• Keep your phone close to the device.\n'
                      '• Check that Bluetooth is turned on.',
                      style: AppTypography.body(context).white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: LayoutConstants.space6),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                key: GoldPathPatrolKeys.connectFF1Retry,
                text: 'Try Again',
                onTap: _startConnectFlow,
                color: AppColor.white,
                textColor: AppColor.primaryBlack,
              ),
            ),
            SizedBox(width: LayoutConstants.space3),
            Expanded(
              child: PrimaryButton(
                key: GoldPathPatrolKeys.connectFF1Cancel,
                text: 'Cancel',
                onTap: _onCancel,
                color: AppColor.white,
                textColor: AppColor.primaryBlack,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bleConnectingOrSuccessView(
    BuildContext context,
    _BleConnectUiPhase phase,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GifView.asset(
                'assets/images/loading.gif',
                width: 139,
                height: 92.67,
                frameRate: 12,
              ),
              const SizedBox(height: 85),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bleTitle(phase),
                      style: AppTypography.h2(context).white,
                    ),
                    SizedBox(height: LayoutConstants.space5),
                    Text(
                      _bleBody(phase),
                      style: AppTypography.body(context).white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        PrimaryButton(
          key: GoldPathPatrolKeys.connectFF1Cancel,
          text: 'Cancel',
          onTap: _onCancel,
          enabled: !_guidedCompletionPending,
          color: AppColor.white,
          textColor: AppColor.primaryBlack,
        ),
      ],
    );
  }

  String _bleTitle(_BleConnectUiPhase phase) {
    return switch (phase) {
      _BleConnectUiPhase.connecting => 'Connecting via Bluetooth...',
      _BleConnectUiPhase.stillConnecting => 'Still connecting…',
      _BleConnectUiPhase.success => 'Connected to FF1',
      _BleConnectUiPhase.bluetoothOff || _BleConnectUiPhase.error =>
        throw StateError('Not a BLE progress phase: $phase'),
    };
  }

  String _bleBody(_BleConnectUiPhase phase) {
    return switch (phase) {
      _BleConnectUiPhase.connecting =>
        'Keep your phone near FF1 and remain on this screen.',
      _BleConnectUiPhase.stillConnecting =>
        'We’re still trying to reach your FF1 over Bluetooth.\n'
            'If this takes more than 15 seconds, you can cancel and try again.',
      _BleConnectUiPhase.success => 'Connected to FF1 — ready to play art.',
      _BleConnectUiPhase.bluetoothOff || _BleConnectUiPhase.error =>
        throw StateError('Not a BLE progress phase: $phase'),
    };
  }

  Widget _bluetoothNotAvailableView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error,
          size: LayoutConstants.iconSizeLarge * 2,
          color: AppColor.feralFileLightBlue,
        ),
        SizedBox(height: LayoutConstants.space4),
        Text(
          'Bluetooth is required for setup. Please turn it on to continue.',
          style: AppTypography.h2(context).white,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: LayoutConstants.space5),
        PrimaryButton(
          text: 'Open Bluetooth Settings',
          onTap: () async {
            AppStructuredLog.logUiAction(
              logger: _log,
              action: 'open_bluetooth_settings',
            );
            await openAppSettings();
          },
        ),
      ],
    );
  }
}
