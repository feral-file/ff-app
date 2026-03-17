import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pointer interaction behavior for an overlay item.
enum OverlayInteractionMode {
  /// Overlay does not consume gestures, allowing taps to pass through.
  tapThrough,

  /// Overlay blocks interactions with widgets underneath.
  blocking,
}

/// Icon preset for toast overlays.
enum ToastOverlayIconPreset {
  /// Loading icon preset.
  loading,

  /// Information icon preset.
  information,
}

/// Base model contract for app-level overlays.
@immutable
abstract class AppOverlayItem {
  /// Creates an [AppOverlayItem].
  const AppOverlayItem({
    required this.id,
    required this.interactionMode,
    required this.isDismissing,
  });

  /// Stable identifier for this overlay instance.
  final String id;

  /// Pointer interaction behavior.
  final OverlayInteractionMode interactionMode;

  /// Whether this overlay is in dismiss animation phase.
  final bool isDismissing;
}

/// Toast overlay model.
@immutable
class AppToastOverlayItem extends AppOverlayItem {
  /// Creates an [AppToastOverlayItem].
  const AppToastOverlayItem({
    required super.id,
    required super.interactionMode,
    required super.isDismissing,
    required this.message,
    required this.iconPreset,
    this.isManuallyDismissible = false,
    this.autoDismissAfter,
  });

  /// Toast message.
  final String message;

  /// Leading icon preset.
  final ToastOverlayIconPreset iconPreset;

  /// Optional auto-dismiss duration.
  final Duration? autoDismissAfter;

  /// Whether the toast can be dismissed via UI controls.
  final bool isManuallyDismissible;

  /// Returns an updated copy.
  AppToastOverlayItem copyWith({
    String? id,
    OverlayInteractionMode? interactionMode,
    bool? isDismissing,
    String? message,
    ToastOverlayIconPreset? iconPreset,
    Duration? autoDismissAfter,
    bool clearAutoDismissAfter = false,
    bool? isManuallyDismissible,
  }) {
    return AppToastOverlayItem(
      id: id ?? this.id,
      interactionMode: interactionMode ?? this.interactionMode,
      isDismissing: isDismissing ?? this.isDismissing,
      message: message ?? this.message,
      iconPreset: iconPreset ?? this.iconPreset,
      autoDismissAfter: clearAutoDismissAfter
          ? null
          : autoDismissAfter ?? this.autoDismissAfter,
      isManuallyDismissible:
          isManuallyDismissible ?? this.isManuallyDismissible,
    );
  }
}

/// Global app overlay store.
final appOverlayProvider =
    NotifierProvider<AppOverlayNotifier, List<AppOverlayItem>>(
      AppOverlayNotifier.new,
    );

/// Writes and mutates app overlay state.
class AppOverlayNotifier extends Notifier<List<AppOverlayItem>> {
  int _nextOverlayId = 0;

  @override
  List<AppOverlayItem> build() {
    return const <AppOverlayItem>[];
  }

  /// Shows a toast overlay and returns its generated id.
  String showToast({
    required String message,
    ToastOverlayIconPreset iconPreset = ToastOverlayIconPreset.loading,
    bool isTapThroughable = true,
    Duration? autoDismissAfter,
  }) {
    final overlayId = 'toast-${_nextOverlayId++}';
    final interactionMode = isTapThroughable
        ? OverlayInteractionMode.tapThrough
        : OverlayInteractionMode.blocking;

    final toast = AppToastOverlayItem(
      id: overlayId,
      interactionMode: interactionMode,
      isDismissing: false,
      message: message,
      iconPreset: iconPreset,
      autoDismissAfter: autoDismissAfter,
    );

    state = [...state, toast];
    return overlayId;
  }

  /// Creates or updates a toast overlay and returns its id.
  ///
  /// If [overlayId] points to an existing toast, this method updates it in
  /// place to avoid remove/re-add flicker during status transitions.
  /// Otherwise, it creates a new toast and returns the new id.
  String upsertToast({
    required String message,
    String? overlayId,
    ToastOverlayIconPreset iconPreset = ToastOverlayIconPreset.loading,
    bool isTapThroughable = true,
    Duration? autoDismissAfter,
  }) {
    final interactionMode = isTapThroughable
        ? OverlayInteractionMode.tapThrough
        : OverlayInteractionMode.blocking;

    if (overlayId == null) {
      return showToast(
        message: message,
        iconPreset: iconPreset,
        isTapThroughable: isTapThroughable,
        autoDismissAfter: autoDismissAfter,
      );
    }

    var found = false;
    state = [
      for (final item in state)
        if (item.id == overlayId && item is AppToastOverlayItem)
          () {
            found = true;
            return item.copyWith(
              isDismissing: false,
              message: message,
              iconPreset: iconPreset,
              interactionMode: interactionMode,
              autoDismissAfter: autoDismissAfter,
              clearAutoDismissAfter: autoDismissAfter == null,
            );
          }()
        else
          item,
    ];

    if (found) {
      return overlayId;
    }

    return showToast(
      message: message,
      iconPreset: iconPreset,
      isTapThroughable: isTapThroughable,
      autoDismissAfter: autoDismissAfter,
    );
  }

  /// Starts dismiss animation for a specific overlay id.
  void dismissOverlay(String overlayId) {
    state = [
      for (final item in state)
        if (item.id == overlayId) _markDismissing(item) else item,
    ];
  }

  /// Removes an overlay from state immediately.
  void removeOverlay(String overlayId) {
    state = [
      for (final item in state)
        if (item.id != overlayId) item,
    ];
  }

  AppOverlayItem _markDismissing(AppOverlayItem item) {
    if (item is AppToastOverlayItem) {
      return item.copyWith(isDismissing: true);
    }
    return item;
  }
}
