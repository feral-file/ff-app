import 'dart:async';

import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _routesThatHideNowDisplayingBar = <String>[
  Routes.onboarding,
  Routes.onboardingIntroducePage,
  Routes.onboardingAddAddressPage,
  Routes.onboardingSetupFf1Page,
  Routes.ff1DevicePickerPage,
  Routes.handleBluetoothDeviceScanDeeplinkPage,
  Routes.connectFF1Page,
  Routes.addAddressPage,
  Routes.addAliasPage,
  Routes.startSetupFf1,
  Routes.scanWifiNetworks,
  Routes.enterWifiPassword,
  Routes.deviceConfiguration,
  Routes.ff1Updating,
  Routes.nowDisplaying,
];

/// Syncs scroll + keyboard visibility into [nowDisplayingVisibilityProvider].
///
/// This keeps the provider pure: it exposes update methods; this widget
/// is responsible for wiring platform/UI signals into those methods.
class NowDisplayingVisibilitySync extends ConsumerStatefulWidget {
  const NowDisplayingVisibilitySync({
    required this.child,
    required this.router,
    super.key,
  });

  final Widget child;
  final GoRouter router;

  @override
  ConsumerState<NowDisplayingVisibilitySync> createState() =>
      _NowDisplayingVisibilitySyncState();
}

class _NowDisplayingVisibilitySyncState
    extends ConsumerState<NowDisplayingVisibilitySync> {
  late final KeyboardVisibilityController _keyboardVisibilityController;
  StreamSubscription<bool>? _keyboardSubscription;

  @override
  void initState() {
    super.initState();
    _keyboardVisibilityController = KeyboardVisibilityController();

    final notifier = ref.read(nowDisplayingVisibilityProvider.notifier);

    _keyboardSubscription = _keyboardVisibilityController.onChange.listen(
      notifier.setKeyboardVisibility,
    );

    // Sync route/location visibility from go_router.
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);

    // Riverpod forbids modifying providers while the widget tree is building.
    // Defer the "initial sync" writes until after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final notifier = ref.read(nowDisplayingVisibilityProvider.notifier);
      notifier.setKeyboardVisibility(_keyboardVisibilityController.isVisible);
      _handleRouteChanged();
    });
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_handleRouteChanged);
    _keyboardSubscription?.cancel();
    super.dispose();
  }

  void _handleRouteChanged() {
    final routeInfo = widget.router.routeInformationProvider.value;
    final path = routeInfo.uri.path.isEmpty ? Routes.home : routeInfo.uri.path;

    ref
        .read(nowDisplayingVisibilityProvider.notifier)
        .setShouldShowNowDisplaying(_shouldShowForPath(path));
  }

  bool _shouldShowForPath(String path) {
    for (final hidden in _routesThatHideNowDisplayingBar) {
      if (path == hidden || path.startsWith('$hidden/')) {
        return false;
      }
    }
    return true;
  }

  bool _onScrollNotification(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    final notifier = ref.read(nowDisplayingVisibilityProvider.notifier);

    switch (notification.direction) {
      case ScrollDirection.reverse:
        notifier.setNowDisplayingVisibility(false);
      case ScrollDirection.forward:
        notifier.setNowDisplayingVisibility(true);
      case ScrollDirection.idle:
        break;
    }

    // Do not stop the notification from bubbling.
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: _onScrollNotification,
      child: widget.child,
    );
  }
}
