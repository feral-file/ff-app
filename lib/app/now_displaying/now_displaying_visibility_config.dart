import 'package:app/app/routing/routes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Route paths where now displaying must not be shown.
///
/// This list mirrors the legacy app behavior for screens that suppress
/// the floating now displaying bar.
const routesThatHideNowDisplayingBar = <String>[
  Routes.onboarding,
  Routes.onboardingIntroducePage,
  Routes.onboardingAddAddressPage,
  Routes.onboardingSetupFf1Page,
  Routes.ff1DeviceScanPage,
  Routes.connectFF1Page,
  Routes.addAddressPage,
  Routes.addAliasPage,
  Routes.startSetupFf1,
  Routes.scanWifiNetworks,
  Routes.enterWifiPassword,
  Routes.deviceConfiguration,
  Routes.ff1Updating,
  Routes.keyboardControl,
  Routes.releaseNotes,
  Routes.releaseNoteDetail,
  Routes.settings,
  Routes.settingsEula,
  Routes.settingsPrivacy,
  Routes.scanQrPage,
];

/// Route type checks that hide the Now Displaying bar (modal/drawer overlays).
///
/// Add new route types here when using showModalBottomSheet, showCupertinoModalPopup,
/// showDialog, etc.
bool _isModalBottomSheet(Route<dynamic> r) => r is ModalBottomSheetRoute;

bool _isCupertinoModalPopup(Route<dynamic> r) => r is CupertinoModalPopupRoute;

final _routeTypeChecksThatHideNowDisplayingBar = <bool Function(Route<dynamic>)>[
  _isModalBottomSheet,
  _isCupertinoModalPopup,
];

/// Returns true when [route] is a modal/drawer that should hide the Now Displaying bar.
bool isRouteThatHidesNowDisplaying(Route<dynamic>? route) {
  if (route == null) return false;
  return _routeTypeChecksThatHideNowDisplayingBar.any((check) => check(route));
}
