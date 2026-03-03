import 'package:app/app/routing/deeplink_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scanner behavior mode.
enum ScanQrMode {
  /// Scan an address.
  address,

  /// Scan a global QR code.
  global,
}

/// Result action after a scan attempt.
enum ScanQrActionType {
  /// Ignore the scan.
  ignore,

  /// Return the scanned value.
  returnScannedValue,

  /// Handle a deeplink.
  handleDeeplink,

  /// Show an error.
  showError,
}

/// Result returned by [ScanQrNotifier.processScan].
class ScanQrAction {
  /// Constructor
  const ScanQrAction({
    required this.type,
    this.value,
  });

  /// The type of action to perform.
  final ScanQrActionType type;

  /// The value to return or handle.
  final String? value;
}

/// UI state for scanner page.
class ScanQrState {
  /// Constructor
  const ScanQrState({
    this.isLoading = false,
    this.isScanDataError = false,
    this.currentCode,
    this.lastInvalidCode,
  });

  /// Whether the scanner is loading.
  final bool isLoading;

  /// Whether the scan data is error.
  final bool isScanDataError;

  /// The current code being scanned.
  final String? currentCode;

  /// The last invalid code scanned.
  final String? lastInvalidCode;

  /// Copy with new state.
  ScanQrState copyWith({
    bool? isLoading,
    bool? isScanDataError,
    String? currentCode,
    String? lastInvalidCode,
    bool clearCurrentCode = false,
    bool clearLastInvalidCode = false,
  }) {
    return ScanQrState(
      isLoading: isLoading ?? this.isLoading,
      isScanDataError: isScanDataError ?? this.isScanDataError,
      currentCode: clearCurrentCode ? null : (currentCode ?? this.currentCode),
      lastInvalidCode: clearLastInvalidCode
          ? null
          : (lastInvalidCode ?? this.lastInvalidCode),
    );
  }
}

/// Provider for the scan QR notifier.
final scanQrProvider = NotifierProvider<ScanQrNotifier, ScanQrState>(
  ScanQrNotifier.new,
);

/// Scanner state machine used by scan_qr_page.
class ScanQrNotifier extends Notifier<ScanQrState> {
  @override
  ScanQrState build() => const ScanQrState();

  /// Process a scan.
  ScanQrAction processScan({
    required String? rawValue,
    required ScanQrMode mode,
  }) {
    if (state.isLoading || rawValue == null || rawValue.isEmpty) {
      return const ScanQrAction(type: ScanQrActionType.ignore);
    }

    if (state.isScanDataError && rawValue == state.lastInvalidCode) {
      return const ScanQrAction(type: ScanQrActionType.ignore);
    }

    state = state.copyWith(currentCode: rawValue);

    if (mode == ScanQrMode.address) {
      return ScanQrAction(
        type: ScanQrActionType.returnScannedValue,
        value: rawValue,
      );
    }

    if (mode == ScanQrMode.global) {
      state = state.copyWith(isLoading: true);

      if (classifyDeeplink(rawValue) != DeeplinkType.unknown) {
        return ScanQrAction(
          type: ScanQrActionType.handleDeeplink,
          value: rawValue,
        );
      }

      return ScanQrAction(
        type: ScanQrActionType.returnScannedValue,
        value: rawValue,
      );
    }

    state = state.copyWith(
      isScanDataError: true,
      lastInvalidCode: rawValue,
    );
    return const ScanQrAction(type: ScanQrActionType.showError);
  }

  /// Clear the error.
  void clearError() {
    state = state.copyWith(
      isScanDataError: false,
      clearLastInvalidCode: true,
    );
  }

  /// Mark the scanner as ready.
  void markReady() {
    state = state.copyWith(isLoading: false);
  }
}
