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
// ignore: specify_nonobvious_property_types
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
  double? _volumeBeforeMute;
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

    final shouldBeMuted = value <= 0;
    final shouldToggleMute = shouldBeMuted != state.isMuted;
    if (shouldBeMuted) {
      final confirmedVolume = _deviceStatus?.volume?.toDouble();
      if (confirmedVolume != null && confirmedVolume > 0) {
        _volumeBeforeMute = confirmedVolume;
      } else if (_volumeBeforeMute == null || _volumeBeforeMute! <= 0) {
        _volumeBeforeMute = 50;
      }
    } else {
      _volumeBeforeMute = value;
    }
    _pendingVolume = value;
    if (shouldToggleMute) {
      _pendingMuted = shouldBeMuted;
    }
    state = _deriveState();

    final control = ref.read(ff1WifiControlProvider);
    try {
      // Preserve legacy slider zero-crossing contract:
      // >0 -> 0 toggles mute on, 0 -> >0 toggles mute off.
      if (shouldToggleMute) {
        await control.toggleMute(topicId: _topicId);
      }
      await control.setVolume(topicId: _topicId, percent: value.round());
    } on Exception {
      // Roll back to the last confirmed device status, not the optimistic
      // draft.
      _pendingVolume = null;
      _pendingMuted = null;
      state = _deriveState();
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
    if (state.isMuted) {
      final restoredVolume = _restoredVolumeAfterMute();
      _pendingVolume = restoredVolume;
      _pendingMuted = false;
    } else {
      final confirmedVolume = _deviceStatus?.volume?.toDouble();
      if (confirmedVolume != null && confirmedVolume > 0) {
        _volumeBeforeMute = confirmedVolume;
      } else if (_pendingVolume != null && _pendingVolume! > 0) {
        _volumeBeforeMute = _pendingVolume;
      } else if (_volumeBeforeMute == null || _volumeBeforeMute! <= 0) {
        _volumeBeforeMute = 50;
      }
      _pendingMuted = true;
    }
    state = _deriveState();

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
      _volumeBeforeMute = null;
      return const FF1AudioControlState.initial();
    }

    final actualVolume = _deviceStatus?.volume?.toDouble();
    final actualMuted = _deviceStatus?.isMuted;
    if (actualVolume != null && actualVolume > 0) {
      _volumeBeforeMute = actualVolume;
    }
    if (actualVolume == null && actualMuted == null) {
      final resolvedMuted = _pendingMuted ?? false;
      final rawVolume = _pendingVolume ?? 50;
      return FF1AudioControlState(
        volume: resolvedMuted ? 0 : rawVolume,
        isMuted: resolvedMuted,
        isTopicActive: true,
      );
    }
    if (_pendingVolume != null &&
        actualVolume != null &&
        _pendingVolume!.roundToDouble() == actualVolume.roundToDouble()) {
      _pendingVolume = null;
    }
    if (_pendingMuted != null && actualMuted == _pendingMuted) {
      _pendingMuted = null;
    }

    final resolvedMuted = _pendingMuted ?? actualMuted ?? false;
    final rawVolume = _resolvedVolume(
      resolvedMuted: resolvedMuted,
      actualVolume: actualVolume,
    );
    // When muted, the device may still report the pre-mute level; the slider
    // should read as 0 so the thumb matches the muted icon tap.
    return FF1AudioControlState(
      volume: resolvedMuted ? 0 : rawVolume,
      isMuted: resolvedMuted,
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
    _volumeBeforeMute = null;
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

  double _resolvedVolume({
    required bool resolvedMuted,
    required double? actualVolume,
  }) {
    final pendingVolume = _pendingVolume;
    if (pendingVolume != null) {
      if (!resolvedMuted && pendingVolume > 0) {
        return pendingVolume;
      }
      if (resolvedMuted) {
        return 0;
      }
    }

    final deviceVolume = actualVolume ?? 50;
    if (resolvedMuted) {
      return 0;
    }
    if (deviceVolume > 0) {
      return deviceVolume;
    }
    return _restoredVolumeAfterMute();
  }

  double _restoredVolumeAfterMute() {
    final volume = _volumeBeforeMute;
    if (volume != null && volume > 0) {
      return volume;
    }
    final confirmedVolume = _deviceStatus?.volume?.toDouble();
    if (confirmedVolume != null && confirmedVolume > 0) {
      return confirmedVolume;
    }
    return 50;
  }
}

/// Family provider for the shared FFP/DDC control surface state.
// ignore: specify_nonobvious_property_types
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
  FfpDdcPanelPower? _pendingPower;

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

    _deviceStatus = ref
        .read(ff1FfpDdcPanelStatusStreamProvider(_topicId))
        .maybeWhen(
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
      _pendingBrightness = null;
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
      _pendingContrast = null;
      state = _deriveState();
      rethrow;
    }
  }

  /// Optimistically updates monitor power and reconciles with a follow-up read.
  Future<void> setPower(FfpDdcPanelPower powerState) async {
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
        powerState: powerState.wireValue,
      );
      // Panel snapshot only arrives via relayer notification; `_deviceStatus`
      // updates from `ff1FfpDdcPanelStatusStreamProvider` when the device
      // pushes. Optimistic `_pendingPower` stays until then.
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
    _pendingPower = _resolvePendingPower(_pendingPower, _deviceStatus.power);

    return _deviceStatus.copyWith(
      brightness: _pendingBrightness ?? _deviceStatus.brightness,
      contrast: _pendingContrast ?? _deviceStatus.contrast,
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
  // When the relayer omits a field, treat the value as unknown rather than
  // keeping an optimistic write alive. That prevents stale snapshots from
  // masquerading as confirmed level values.
  if (actual == null) {
    return null;
  }
  if (pending == null) {
    return null;
  }
  return pending == actual ? null : pending;
}

/// Reconciles optimistic monitor power with relayer [actual] power.
///
/// When [actual] is null (relayer omitted `power` on this push), returns null
/// so pending power on `FF1FfpDdcControlNotifier` is cleared. The notifier then
/// derives effective `power` as null until a later status includes `power`
/// again (`FfpDdcPanelStatus`: unknown power, not "assume last known").
///
/// UI: `availableFfpMonitorPowerModes` in `ffp_monitor_ddc_section.dart` shows
/// no On/Standby/Off actions when power is null—avoiding a wake path the
/// relayer has not confirmed. A common trigger is an incomplete snapshot after
/// power-off (e.g. only monitor name, no `power` field); control is one-way
/// until a complete push restores `power`. Widget regression:
/// `test/unit/widgets/ffp_monitor_ddc_section_test.dart` (incomplete off
/// snapshot).
FfpDdcPanelPower? _resolvePendingPower(
  FfpDdcPanelPower? pending,
  FfpDdcPanelPower? actual,
) {
  if (actual == null) {
    return null;
  }
  if (pending == null) {
    return null;
  }
  return pending == actual ? null : pending;
}
