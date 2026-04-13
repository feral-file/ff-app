//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:app/app/providers/ff1_setup_orchestrator_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/app/providers/onboarding_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/constants/constants.dart';
import 'package:app/domain/models/ff1_device_info.dart';
import 'package:app/ui/screens/ff1_setup/connect_ff1_page.dart';
import 'package:app/ui/screens/ff1_setup/ff1_device_scan_page.dart';
import 'package:app/ui/screens/onboarding/introduce_page.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/buttons/custom_primary_button.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

final _log = Logger('StartSetupFf1Page');

/// Payload for the start setup FF1 page
class StartSetupFf1PagePayload {
  /// Constructor
  StartSetupFf1PagePayload({
    this.deeplink,
    this.selectedDevice,
  });

  /// Deeplink to the device connect screen
  final String? deeplink;

  /// Selected device to setup
  final BluetoothDevice? selectedDevice;

  /// Get data from a device connect deeplink
  List<String> getDataFromLink(String link) {
    final prefix =
        deviceConnectDeepLinks.firstWhereOrNull(
          (prefix) => link.startsWith(prefix),
        ) ??
        '';
    var path = link.replaceFirst(prefix, '');
    if (path.startsWith('/')) {
      path = path.substring(1); // Remove leading slash if present
    }
    // Decode percent-encoded characters (e.g. '%7C' for '|') before
    // splitting. This fixes a case on some Android camera apps
    // (e.g., Google Pixel default camera) where the scanned deeplink
    // path includes encoded separators.
    final encodedPath = Uri.decodeFull(path);
    final data = encodedPath.split('|');
    // Dont remove empty elements, as they are used to indicate
    // the absence of a value
    // ..removeWhere(
    //   (element) => element.isEmpty,
    // );
    return data;
  }

  /// Get the name of the device
  String? get deviceName {
    if (selectedDevice != null) {
      return selectedDevice!.advName;
    }

    if (deeplink == null) {
      return null;
    }

    final data = getDataFromLink(deeplink!);
    return data.firstOrNull;
  }
}

/// Start FF1 setup page
class StartSetupFf1Page extends ConsumerStatefulWidget {
  /// Constructor
  const StartSetupFf1Page({required this.payload, super.key});

  /// Payload for the page
  final StartSetupFf1PagePayload payload;

  @override
  ConsumerState<StartSetupFf1Page> createState() => _StartSetupFf1PageState();
}

class _StartSetupFf1PageState extends ConsumerState<StartSetupFf1Page> {
  late final FF1SetupOrchestratorNotifier _setupOrchestrator;

  @override
  void initState() {
    super.initState();
    _setupOrchestrator = ref.read(ff1SetupOrchestratorProvider.notifier);
  }

  @override
  void dispose() {
    // The guided setup session is created from this entry surface, so if the
    // page leaves the tree without a completed setup we must abandon that
    // session. The orchestrator ignores already-finished sessions.
    unawaited(
      _setupOrchestrator.cancelSession(FF1SetupSessionCancelReason.userAborted),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceName = widget.payload.deviceName;
    final shouldReserveNowDisplayingBar = ref.watch(
      nowDisplayingShouldShowProvider,
    );
    final reservedBottomBarHeight = shouldReserveNowDisplayingBar
        ? LayoutConstants.nowDisplayingBarReservedHeight
        : 0.0;
    final bottomInset = reservedBottomBarHeight;

    final isDeeplinkFlow = widget.payload.deeplink != null;
    final hasDoneOnboarding = ref
        .watch(hasDoneOnboardingProvider)
        .maybeWhen(
          data: (v) => v,
          orElse: () => false,
        );
    final canPopSetup = !(isDeeplinkFlow && !hasDoneOnboarding);

    return PopScope(
      canPop: canPopSetup,
      child: Scaffold(
        backgroundColor: PrimitivesTokens.colorsDarkGrey,
        appBar: SetupAppBar(
          title: 'Setup FF1',
          hasBackButton: canPopSetup,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: LayoutConstants.setupPageHorizontal,
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: LayoutConstants.space12),
                      _HeroIllustration(),
                      SizedBox(height: LayoutConstants.space12),
                      _BodyCopy(
                        deviceName: deviceName,
                      ),
                      SizedBox(height: LayoutConstants.space12),
                    ],
                  ),
                ),
                Positioned(
                  bottom: LayoutConstants.space4 + bottomInset,
                  left: 0,
                  right: 0,
                  child: _StartButton(
                    text: 'Continue',
                    onPressed: () async {
                      // QR scans carry deeplink data into the setup flow.
                      if (widget.payload.deeplink != null) {
                        await _handleQRBasedSetup(widget.payload.deeplink!);
                      }
                      // BLE picker entries already resolved the device.
                      else if (widget.payload.selectedDevice != null) {
                        await _handleSelectedDeviceSetup();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleQRBasedSetup(String deeplink) async {
    // Validate before ensureActiveSetupSession so a malformed QR does not
    // leave a guided session active until this route disposes.
    final ff1DeviceInfo = FF1DeviceInfo.fromDeeplink(deeplink);
    if (ff1DeviceInfo == null) {
      _log.warning('[StartSetupFf1Page] Invalid deeplink: $deeplink');
      return;
    }

    final hasDoneOnboarding = await ref.read(hasDoneOnboardingProvider.future);
    if (!mounted) {
      return;
    }

    _setupOrchestrator.ensureActiveSetupSession();

    if (hasDoneOnboarding) {
      await context.push(
        Routes.ff1DeviceScanPage,
        extra: FF1DeviceScanPagePayload(
          ff1Name: ff1DeviceInfo.name,
          onFF1Selected: (device) {
            unawaited(
              context.push(
                Routes.connectFF1Page,
                extra: ConnectFF1PagePayload(
                  device: device,
                  ff1DeviceInfo: ff1DeviceInfo,
                ),
              ),
            );
          },
        ),
      );
    } else {
      await context.push(
        Routes.onboardingIntroducePage,
        extra: IntroducePagePayload(
          deeplink: deeplink,
        ),
      );
    }
  }

  Future<void> _handleSelectedDeviceSetup() async {
    _setupOrchestrator.ensureActiveSetupSession();
    final device = widget.payload.selectedDevice!;
    _log.info(
      '[StartSetupFf1Page] Starting setup for selected device: '
      '${device.advName}',
    );
    unawaited(
      context.push(
        Routes.connectFF1Page,
        extra: ConnectFF1PagePayload(
          device: device,
          ff1DeviceInfo: null,
        ),
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 247,
        width: 305,
        child: SvgPicture.asset(
          'assets/images/ff1_case.svg',
        ),
      ),
    );
  }
}

class _BodyCopy extends StatelessWidget {
  const _BodyCopy({
    this.deviceName,
  });

  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome to FF1',
          style: AppTypography.h2(context).white,
        ),
        SizedBox(height: LayoutConstants.space5),
        Text(
          "Thanks for being here. You're among the first people to bring "
          'FF1 into your space and explore new ways to live with digital '
          'art.\n\n'
          'FF1 is designed to make playing digital art simple, reliable, '
          'and part of your everyday life. As an early adopter, your '
          'experience will help us understand how FF1 fits into real spaces '
          'and routines—and where we should take it next.\n\n',
          style: AppTypography.body(context).white,
        ),
      ],
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.onPressed,
    required this.text,
  });

  final VoidCallback onPressed;
  final String text;

  @override
  Widget build(BuildContext context) {
    return CustomPrimaryButton(
      padding: const EdgeInsets.only(top: 13, bottom: 10),
      color: PrimitivesTokens.colorsLightBlue,
      onTap: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: AppTypography.body(context).black,
          ),
        ],
      ),
    );
  }
}
