import 'package:app/app/now_displaying/now_displaying_visibility_sync.dart';
import 'package:app/app/providers/current_route_provider.dart';
import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

final log = Logger('NowDisplayingVisibilityProvider');

@immutable
class NowDisplayingVisibilityState {
  const NowDisplayingVisibilityState({
    required this.shouldShowNowDisplaying,
    required this.nowDisplayingVisibility,
    required this.bottomSheetVisibility,
    required this.keyboardVisibility,
    required this.hasFF1,
    required this.workDetailPanelExpanded,
  });

  const NowDisplayingVisibilityState.initial()
    : shouldShowNowDisplaying = true,
      nowDisplayingVisibility = true,
      bottomSheetVisibility = false,
      keyboardVisibility = false,
      hasFF1 = false,
      workDetailPanelExpanded = false;

  final bool shouldShowNowDisplaying;
  final bool nowDisplayingVisibility;
  final bool bottomSheetVisibility;
  final bool keyboardVisibility;

  /// Whether there is at least one paired FF1 device (active or not)
  final bool hasFF1;

  /// When true, work detail info panel is expanded; hide the bar.
  final bool workDetailPanelExpanded;

  bool get shouldShow {
    final shouldShow =
        shouldShowNowDisplaying &&
        nowDisplayingVisibility &&
        !bottomSheetVisibility &&
        !keyboardVisibility &&
        !workDetailPanelExpanded &&
        hasFF1;
    if (shouldShow) {
      log.info('shouldShow: $shouldShow');
    } else {
      log.info('shouldShow: $shouldShow');
    }
    return shouldShow;
  }

  NowDisplayingVisibilityState copyWith({
    bool? shouldShowNowDisplaying,
    bool? nowDisplayingVisibility,
    bool? bottomSheetVisibility,
    bool? keyboardVisibility,
    bool? hasFF1,
    bool? workDetailPanelExpanded,
  }) {
    return NowDisplayingVisibilityState(
      shouldShowNowDisplaying:
          shouldShowNowDisplaying ?? this.shouldShowNowDisplaying,
      nowDisplayingVisibility:
          nowDisplayingVisibility ?? this.nowDisplayingVisibility,
      bottomSheetVisibility:
          bottomSheetVisibility ?? this.bottomSheetVisibility,
      keyboardVisibility: keyboardVisibility ?? this.keyboardVisibility,
      hasFF1: hasFF1 ?? this.hasFF1,
      workDetailPanelExpanded:
          workDetailPanelExpanded ?? this.workDetailPanelExpanded,
    );
  }
}

final nowDisplayingVisibilityProvider =
    NotifierProvider<
      NowDisplayingVisibilityNotifier,
      NowDisplayingVisibilityState
    >(
      NowDisplayingVisibilityNotifier.new,
    );

final nowDisplayingShouldShowProvider = Provider<bool>((ref) {
  return ref.watch(nowDisplayingVisibilityProvider.select((s) => s.shouldShow));
});

class NowDisplayingVisibilityNotifier
    extends Notifier<NowDisplayingVisibilityState> {
  @override
  NowDisplayingVisibilityState build() {
    // Listen to all paired FF1 devices
    ref.listen(allFF1BluetoothDevicesProvider, (previous, next) {
      next.whenData((devices) {
        final hasFF1 = devices.isNotEmpty;
        if (state.hasFF1 != hasFF1) {
          state = state.copyWith(hasFF1: hasFF1);
        }
      });
    });

    // Listen to current route (path + modal/drawer) from AppRouteObserver.
    // Route (modal/drawer) has higher priority than path: when modal/drawer
    // is shown, hide regardless of path.
    ref.listen(currentRouteProvider, (previous, next) {
      // After scroll-down hides the bar, show it again when navigation or the
      // modal stack changes so the user always sees context on a new screen.
      final shouldResetScrollVisibility =
          previous != null &&
          (previous.path != next.path ||
              previous.currentRoute != next.currentRoute);
      _applyRouteState(
        next,
        resetScrollVisibility: shouldResetScrollVisibility,
      );
    });

    // When FF1 advances to another work or playlist, surface the bar again.
    ref.listen(ff1CurrentPlayerStatusProvider, (previous, next) {
      if (previous == null) return;
      if (next == null) return;
      final playlistChanged = previous.playlistId != next.playlistId;
      final indexChanged = previous.currentWorkIndex != next.currentWorkIndex;
      if (playlistChanged || indexChanged) {
        state = state.copyWith(nowDisplayingVisibility: true);
      }
    });

    // Initial sync from current route state
    final routeState = ref.read(currentRouteProvider);
    return _initialStateFromRoute(routeState);
  }

  void _applyRouteState(
    AppRouteState routeState, {
    bool resetScrollVisibility = false,
  }) {
    state = state.copyWith(
      shouldShowNowDisplaying: shouldShowNowDisplayingForRoute(routeState),
      bottomSheetVisibility: routeState.hasModalOrDrawer,
      nowDisplayingVisibility: resetScrollVisibility || state.nowDisplayingVisibility,
    );
  }

  NowDisplayingVisibilityState _initialStateFromRoute(
    AppRouteState routeState,
  ) {
    return const NowDisplayingVisibilityState.initial().copyWith(
      shouldShowNowDisplaying: shouldShowNowDisplayingForRoute(routeState),
      bottomSheetVisibility: routeState.hasModalOrDrawer,
    );
  }

  void setShouldShowNowDisplaying(bool value) {
    state = state.copyWith(shouldShowNowDisplaying: value);
  }

  void setNowDisplayingVisibility(bool value) {
    state = state.copyWith(nowDisplayingVisibility: value);
  }

  void setBottomSheetVisibility(bool value) {
    state = state.copyWith(bottomSheetVisibility: value);
  }

  void setKeyboardVisibility(bool value) {
    state = state.copyWith(keyboardVisibility: value);
  }

  void setWorkDetailPanelExpanded(bool value) {
    state = state.copyWith(workDetailPanelExpanded: value);
  }
}
