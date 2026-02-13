import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class NowDisplayingVisibilityState {
  const NowDisplayingVisibilityState({
    required this.shouldShowNowDisplaying,
    required this.nowDisplayingVisibility,
    required this.bottomSheetVisibility,
    required this.keyboardVisibility,
  });

  const NowDisplayingVisibilityState.initial()
    : shouldShowNowDisplaying = true,
      nowDisplayingVisibility = true,
      bottomSheetVisibility = false,
      keyboardVisibility = false;

  final bool shouldShowNowDisplaying;
  final bool nowDisplayingVisibility;
  final bool bottomSheetVisibility;
  final bool keyboardVisibility;

  bool get shouldShow =>
      shouldShowNowDisplaying &&
      nowDisplayingVisibility &&
      !bottomSheetVisibility &&
      !keyboardVisibility;

  NowDisplayingVisibilityState copyWith({
    bool? shouldShowNowDisplaying,
    bool? nowDisplayingVisibility,
    bool? bottomSheetVisibility,
    bool? keyboardVisibility,
  }) {
    return NowDisplayingVisibilityState(
      shouldShowNowDisplaying:
          shouldShowNowDisplaying ?? this.shouldShowNowDisplaying,
      nowDisplayingVisibility:
          nowDisplayingVisibility ?? this.nowDisplayingVisibility,
      bottomSheetVisibility:
          bottomSheetVisibility ?? this.bottomSheetVisibility,
      keyboardVisibility: keyboardVisibility ?? this.keyboardVisibility,
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
  NowDisplayingVisibilityState build() =>
      const NowDisplayingVisibilityState.initial();

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
