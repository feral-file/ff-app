import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
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
  });

  const NowDisplayingVisibilityState.initial()
    : shouldShowNowDisplaying = true,
      nowDisplayingVisibility = true,
      bottomSheetVisibility = false,
      keyboardVisibility = false,
      hasFF1 = false;

  final bool shouldShowNowDisplaying;
  final bool nowDisplayingVisibility;
  final bool bottomSheetVisibility;
  final bool keyboardVisibility;

  /// Whether there is at least one paired FF1 device (active or not)
  final bool hasFF1;

  bool get shouldShow {
    final shouldShow =
        shouldShowNowDisplaying &&
        nowDisplayingVisibility &&
        !bottomSheetVisibility &&
        !keyboardVisibility &&
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

    return const NowDisplayingVisibilityState.initial();
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
}
