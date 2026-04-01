import 'package:app/app/providers/ff1_bluetooth_device_providers.dart';
import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1/ffp_ddc_panel_status.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider-owned UI state for the main FF1 audio control surface.
class FF1AudioControlState {
  /// Creates an audio control state snapshot.
  const FF1AudioControlState({
    required this.volume,
    required this.isMuted,
    required this.isTopicActive,
  });

  /// Default idle state used when the scoped topic is not the active FF1.
  const FF1AudioControlState.initial()
    : volume = 50,
      isMuted = false,
      isTopicActive = false;

  /// The effective volume shown in the UI.
  final double volume;

  /// Whether the UI should render the muted icon state.
  final bool isMuted;

  /// Whether this provider's topic still matches the active FF1.
  final bool isTopicActive;

  /// Returns a copy with selective field overrides.
  FF1AudioControlState copyWith({
    double? volume,
    bool? isMuted,
    bool? isTopicActive,
  }) {
    return FF1AudioControlState(
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isTopicActive: isTopicActive ?? this.isTopicActive,
    );
  }
}

/// Family provider for the shared FF1 audio control surface state.
final ff1AudioControlProvider = NotifierProvider.autoDispose
    .family<FF1AudioControlNotifier, FF1AudioControlState, String>(
      FF1AudioControlNotifier.new,
    );

/// Owns optimistic FF1 audio control state and command dispatch.
class FF1AudioControlNotifier extends Notifier<FF1AudioControlState> {
  /// Creates a notifier scoped to one FF1 topic.
  FF1AudioControlNotifier(this._topicId);

  final String _topicId;
  String? _activeTopicId;
  FF1DeviceStatus? _deviceStatus;
  double? _pendingVolume;
  bool? _pendingMuted;

  @override
  FF1AudioControlState build() {
    _syncActiveTopic();
    ref
      ..listen<AsyncValue<FF1Device?>>(
        activeFF1BluetoothDeviceProvider,
        (previous, next) {
          _syncActiveTopic();
          _recompute();
        },
      )
      ..listen<FF1DeviceStatus?>(ff1CurrentDeviceStatusProvider, (
        previous,
        next,
      ) {
        _deviceStatus = next;
        _recompute();
      });

    final currentStatus = ref.read(ff1CurrentDeviceStatusProvider);
    if (currentStatus != null) {
      _deviceStatus = currentStatus;
    }
    return _deriveState();
  }

  /// Commits a volume write after the user finishes dragging the slider.
  Future<void> commitVolume(double value) async {
    if (!state.isTopicActive) {
      return;
    }

    final previousState = state;
    _pendingVolume = value;
    state = state.copyWith(volume: value);

    final control = ref.read(ff1WifiControlProvider);
    try {
      await control.setVolume(topicId: _topicId, percent: value.round());
    } on Exception {
      _pendingVolume = null;
      state = previousState;
      rethrow;
    }
  }

  /// Updates the optimistic slider value during drag interaction.
  void setVolumeDraft(double value) {
    if (!state.isTopicActive) {
      return;
    }
    _pendingVolume = value;
    state = state.copyWith(volume: value);
  }

  /// Optimistically toggles mute and rolls back on command failure.
  Future<void> toggleMute() async {
    if (!state.isTopicActive) {
      return;
    }

    final previousState = state;
    _pendingMuted = !state.isMuted;
    state = state.copyWith(isMuted: _pendingMuted);

    final control = ref.read(ff1WifiControlProvider);
    try {
      await control.toggleMute(topicId: _topicId);
    } on Exception {
      _pendingMuted = null;
      state = previousState;
      rethrow;
    }
  }

  void _recompute() {
    state = _deriveState();
  }

  FF1AudioControlState _deriveState() {
    final isTopicActive = _isActiveTopic();
    if (!isTopicActive) {
      _pendingVolume = null;
      _pendingMuted = null;
      return const FF1AudioControlState.initial();
    }

    final actualVolume = _deviceStatus?.volume?.toDouble();
    final actualMuted = _deviceStatus?.isMuted;
    if (actualVolume == null && actualMuted == null) {
      return FF1AudioControlState(
        volume: _pendingVolume ?? 50,
        isMuted: _pendingMuted ?? false,
        isTopicActive: true,
      );
    }
    if (_pendingVolume != null && actualVolume == _pendingVolume) {
      _pendingVolume = null;
    }
    if (_pendingMuted != null && actualMuted == _pendingMuted) {
      _pendingMuted = null;
    }

    return FF1AudioControlState(
      volume: _pendingVolume ?? actualVolume ?? 50,
      isMuted: _pendingMuted ?? actualMuted ?? false,
      isTopicActive: true,
    );
  }

  void _syncActiveTopic() {
    final activeTopicId = _currentActiveTopicId();
    if (activeTopicId.isEmpty || _activeTopicId == activeTopicId) {
      _activeTopicId = activeTopicId;
      return;
    }

    if (_activeTopicId == null || _activeTopicId!.isEmpty) {
      _activeTopicId = activeTopicId;
      return;
    }

    _activeTopicId = activeTopicId;
    _deviceStatus = null;
    _pendingVolume = null;
    _pendingMuted = null;
  }

  String _currentActiveTopicId() {
    final activeDeviceAsync = ref.read(activeFF1BluetoothDeviceProvider);
    return activeDeviceAsync.maybeWhen(
      data: (device) => device?.topicId ?? '',
      orElse: () => '',
    );
  }

  bool _isActiveTopic() {
    final activeDeviceAsync = ref.read(activeFF1BluetoothDeviceProvider);
    final activeTopicId = activeDeviceAsync.maybeWhen(
      data: (device) => device?.topicId ?? '',
      orElse: () => '',
    );
    return activeTopicId == _topicId;
  }
}

/// Family provider for the shared FFP/DDC control surface state.
final ff1FfpDdcControlProvider = NotifierProvider.autoDispose
    .family<FF1FfpDdcControlNotifier, FfpDdcPanelStatus, String>(
      FF1FfpDdcControlNotifier.new,
    );

/// Owns optimistic FFP/DDC monitor state and command dispatch.
class FF1FfpDdcControlNotifier extends Notifier<FfpDdcPanelStatus> {
  /// Creates a notifier scoped to one FF1 topic.
  FF1FfpDdcControlNotifier(this._topicId);

  final String _topicId;
  String? _activeTopicId;
  FfpDdcPanelStatus _deviceStatus = const FfpDdcPanelStatus();
  int? _pendingBrightness;
  int? _pendingContrast;
  int? _pendingVolume;
  String? _pendingPower;

  @override
  FfpDdcPanelStatus build() {
    _syncActiveTopic();
    ref
      ..listen<AsyncValue<FF1Device?>>(
        activeFF1BluetoothDeviceProvider,
        (previous, next) {
          _syncActiveTopic();
          _recompute();
        },
      )
      ..listen<AsyncValue<FfpDdcPanelStatus>>(
        ff1FfpDdcPanelStatusStreamProvider(_topicId),
        (previous, next) {
          next.whenData((status) {
            _deviceStatus = status;
            _recompute();
          });
        },
      );

    final streamState = ref.read(ff1FfpDdcPanelStatusStreamProvider(_topicId));
    _deviceStatus = streamState.maybeWhen(
      data: (status) => status,
      orElse: () => const FfpDdcPanelStatus(),
    );
    return _deriveState();
  }

  /// Updates the optimistic brightness value during slider drag.
  void setBrightnessDraft(double value) {
    if (!_isActiveTopic()) {
      return;
    }
    _pendingBrightness = value.round();
    state = _deriveState();
  }

  /// Commits a brightness write and rolls back on failure.
  Future<void> commitBrightness(double value) async {
    if (!_isActiveTopic()) {
      return;
    }

    final previousPending = _pendingBrightness;
    _pendingBrightness = value.round();
    state = _deriveState();

    final control = ref.read(ff1WifiControlProvider);
    try {
      await control.setFfpMonitorBrightness(
        topicId: _topicId,
        monitorId: _monitorId(state),
        percent: value.round(),
      );
    } on Exception {
      _pendingBrightness = previousPending;
      state = _deriveState();
      rethrow;
    }
  }

  /// Updates the optimistic contrast value during slider drag.
  void setContrastDraft(double value) {
    if (!_isActiveTopic()) {
      return;
    }
    _pendingContrast = value.round();
    state = _deriveState();
  }

  /// Commits a contrast write and rolls back on failure.
  Future<void> commitContrast(double value) async {
    if (!_isActiveTopic()) {
      return;
    }

    final previousPending = _pendingContrast;
    _pendingContrast = value.round();
    state = _deriveState();

    final control = ref.read(ff1WifiControlProvider);
    try {
      await control.setFfpMonitorContrast(
        topicId: _topicId,
        monitorId: _monitorId(state),
        percent: value.round(),
      );
    } on Exception {
      _pendingContrast = previousPending;
      state = _deriveState();
      rethrow;
    }
  }

  /// Updates the optimistic monitor-volume value during slider drag.
  void setVolumeDraft(double value) {
    if (!_isActiveTopic()) {
      return;
    }
    _pendingVolume = value.round();
    state = _deriveState();
  }

  /// Commits a monitor-volume write and rolls back on failure.
  Future<void> commitVolume(double value) async {
    if (!_isActiveTopic()) {
      return;
    }

    final previousPending = _pendingVolume;
    _pendingVolume = value.round();
    state = _deriveState();

    final control = ref.read(ff1WifiControlProvider);
    try {
      await control.setFfpMonitorVolume(
        topicId: _topicId,
        monitorId: _monitorId(state),
        percent: value.round(),
      );
    } on Exception {
      _pendingVolume = previousPending;
      state = _deriveState();
      rethrow;
    }
  }

  /// Optimistically updates monitor power and reconciles with a follow-up read.
  Future<void> setPower(String powerState) async {
    if (!_isActiveTopic()) {
      return;
    }

    final previousPending = _pendingPower;
    _pendingPower = powerState;
    state = _deriveState();

    final control = ref.read(ff1WifiControlProvider);
    try {
      await control.setFfpMonitorPower(
        topicId: _topicId,
        monitorId: _monitorId(state),
        powerState: powerState,
      );
      try {
        final fresh = await control.getFfpDdcPanelStatus(topicId: _topicId);
        _deviceStatus = fresh;
      } on Exception {
        // Keep waiting for either the explicit refresh or relayer push to
        // confirm the power state; the optimistic value remains visible.
      }
      state = _deriveState();
    } on Exception {
      _pendingPower = previousPending;
      state = _deriveState();
      rethrow;
    }
  }

  void _recompute() {
    state = _deriveState();
  }

  FfpDdcPanelStatus _deriveState() {
    if (!_isActiveTopic()) {
      _pendingBrightness = null;
      _pendingContrast = null;
      _pendingVolume = null;
      _pendingPower = null;
      return const FfpDdcPanelStatus();
    }

    _pendingBrightness = _resolvePendingInt(
      _pendingBrightness,
      _deviceStatus.brightness,
    );
    _pendingContrast = _resolvePendingInt(
      _pendingContrast,
      _deviceStatus.contrast,
    );
    _pendingVolume = _resolvePendingInt(_pendingVolume, _deviceStatus.volume);
    _pendingPower = _resolvePendingPower(_pendingPower, _deviceStatus.power);

    return _deviceStatus.copyWith(
      brightness: _pendingBrightness ?? _deviceStatus.brightness,
      contrast: _pendingContrast ?? _deviceStatus.contrast,
      volume: _pendingVolume ?? _deviceStatus.volume,
      power: _pendingPower ?? _deviceStatus.power,
    );
  }

  String _monitorId(FfpDdcPanelStatus status) =>
      status.monitor?.trim().isNotEmpty ?? false
      ? status.monitor!.trim()
      : 'default';

  bool _isActiveTopic() {
    final activeDeviceAsync = ref.read(activeFF1BluetoothDeviceProvider);
    final activeTopicId = activeDeviceAsync.maybeWhen(
      data: (device) => device?.topicId ?? '',
      orElse: () => '',
    );
    return activeTopicId == _topicId;
  }

  void _syncActiveTopic() {
    final activeTopicId = _currentActiveTopicId();
    if (activeTopicId.isEmpty || _activeTopicId == activeTopicId) {
      _activeTopicId = activeTopicId;
      return;
    }

    if (_activeTopicId == null || _activeTopicId!.isEmpty) {
      _activeTopicId = activeTopicId;
      return;
    }

    _activeTopicId = activeTopicId;
    _deviceStatus = const FfpDdcPanelStatus();
    _pendingBrightness = null;
    _pendingContrast = null;
    _pendingVolume = null;
    _pendingPower = null;
  }

  String _currentActiveTopicId() {
    final activeDeviceAsync = ref.read(activeFF1BluetoothDeviceProvider);
    return activeDeviceAsync.maybeWhen(
      data: (device) => device?.topicId ?? '',
      orElse: () => '',
    );
  }
}

int? _resolvePendingInt(int? pending, int? actual) {
  if (pending == null) {
    return null;
  }
  return pending == actual ? null : pending;
}

String? _resolvePendingPower(String? pending, String? actual) {
  if (pending == null) {
    return null;
  }
  return _normalizePowerKey(pending) == _normalizePowerKey(actual)
      ? null
      : pending;
}

String? _normalizePowerKey(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'on':
    case 'poweron':
      return 'on';
    case 'off':
    case 'poweroff':
      return 'off';
    case 'standby':
    case 'suspend':
      return 'standby';
    default:
      return null;
  }
}
