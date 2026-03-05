import 'dart:async';

import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Route paths where now displaying must not be shown.
///
/// This list mirrors the legacy app behavior for screens that suppress
/// the floating now displaying bar.
const routesThatHideNowDisplayingBar = <String>[
  Routes.onboarding,
  Routes.onboardingIntroducePage,
  Routes.onboardingAddAddressPage,
  Routes.onboardingSetupFf1Page,
  Routes.ff1DevicePickerPage,
  Routes.connectFF1Page,
  Routes.addAddressPage,
  Routes.addAliasPage,
  Routes.startSetupFf1,
  Routes.scanWifiNetworks,
  Routes.enterWifiPassword,
  Routes.deviceConfiguration,
  Routes.ff1Updating,
  Routes.nowDisplaying,
  Routes.keyboardControl,
  Routes.releaseNotes,
  Routes.releaseNoteDetail,
  Routes.settings,
  Routes.settingsEula,
  Routes.settingsPrivacy,
  Routes.scanQrPage,
];

/// Minimum scrollable content extent required before scroll should toggle
/// now displaying visibility.
const nowDisplayingScrollToggleThreshold = 100.0;

/// Returns true when the now displaying bar should be visible for [path].
bool shouldShowNowDisplayingForPath(String path) {
  for (final hidden in routesThatHideNowDisplayingBar) {
    if (path == hidden || path.startsWith('$hidden/')) {
      return false;
    }
  }
  return true;
}

/// Returns true if a scroll event should affect now displaying visibility.
bool shouldReactToNowDisplayingScroll({
  required Axis axis,
  required double maxScrollExtent,
}) {
  return axis == Axis.vertical &&
      maxScrollExtent >= nowDisplayingScrollToggleThreshold;
}

/// Syncs scroll + keyboard visibility into [nowDisplayingVisibilityProvider].
///
/// This keeps the provider pure: it exposes update methods; this widget
/// is responsible for wiring platform/UI signals into those methods.
class NowDisplayingVisibilitySync extends ConsumerStatefulWidget {
  /// Creates a [NowDisplayingVisibilitySync].
  const NowDisplayingVisibilitySync({
    required this.child,
    required this.router,
    super.key,
  });

  /// Subtree that sends scroll notifications for visibility sync.
  final Widget child;

  /// Router used to map current path into show/hide visibility.
  final GoRouter router;

  @override
  ConsumerState<NowDisplayingVisibilitySync> createState() =>
      _NowDisplayingVisibilitySyncState();
}

class _NowDisplayingVisibilitySyncState
    extends ConsumerState<NowDisplayingVisibilitySync> {
  late final KeyboardVisibilityController _keyboardVisibilityController;
  late final StreamSubscription<bool> _keyboardSubscription;

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

      ref
          .read(nowDisplayingVisibilityProvider.notifier)
          .setKeyboardVisibility(_keyboardVisibilityController.isVisible);
      _handleRouteChanged();
    });
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_handleRouteChanged);
    unawaited(_keyboardSubscription.cancel());
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
    return shouldShowNowDisplayingForPath(path);
  }

  bool _onScrollNotification(UserScrollNotification notification) {
    if (!shouldReactToNowDisplayingScroll(
      axis: notification.metrics.axis,
      maxScrollExtent: notification.metrics.maxScrollExtent,
    )) {
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
