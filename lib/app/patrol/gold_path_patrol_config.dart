import 'package:app/domain/models/ff1_device.dart';

/// Strongly typed config for the gold-path Patrol test.
class GoldPathPatrolConfig {
  /// Creates an [GoldPathPatrolConfig].
  const GoldPathPatrolConfig({
    required this.ff1DeviceId,
    required this.ff1TopicId,
    required this.canaryChannelTitle,
    this.ff1Name = 'Gold Path Test FF1',
    this.ff1RemoteId = '00:00:00:00:00:00',
    this.ff1BranchName = 'release',
    this.canaryChannelId,
    this.canaryWorkId,
    this.canaryWorkTitle,
    this.soakDuration = Duration.zero,
  });

  /// Reads the config from compile-time environment variables.
  factory GoldPathPatrolConfig.fromEnvironment(Map<String, String> env) {
    String requiredValue(String key) {
      final value = env[key]?.trim() ?? '';
      if (value.isEmpty) {
        throw StateError('Missing required Patrol config: $key');
      }
      return value;
    }

    Duration parseSoakDuration() {
      final seconds = int.tryParse(env[_soakSecondsKey]?.trim() ?? '');
      if (seconds != null && seconds >= 0) {
        return Duration(seconds: seconds);
      }

      final minutes = int.tryParse(env[_soakMinutesKey]?.trim() ?? '');
      if (minutes != null && minutes >= 0) {
        return Duration(minutes: minutes);
      }

      return Duration.zero;
    }

    return GoldPathPatrolConfig(
      ff1DeviceId: requiredValue(_ff1DeviceIdKey),
      ff1TopicId: requiredValue(_ff1TopicIdKey),
      ff1Name: env[_ff1NameKey]?.trim().nonEmptyOrNull ?? 'Gold Path Test FF1',
      ff1RemoteId:
          env[_ff1RemoteIdKey]?.trim().nonEmptyOrNull ?? '00:00:00:00:00:00',
      ff1BranchName: env[_ff1BranchNameKey]?.trim().nonEmptyOrNull ?? 'release',
      canaryChannelId: env[_canaryChannelIdKey]?.trim().nonEmptyOrNull,
      canaryChannelTitle: requiredValue(_canaryChannelTitleKey),
      canaryWorkId: env[_canaryWorkIdKey]?.trim().nonEmptyOrNull,
      canaryWorkTitle: env[_canaryWorkTitleKey]?.trim().nonEmptyOrNull,
      soakDuration: parseSoakDuration(),
    );
  }

  /// Reads the config from compile-time `--dart-define` values.
  factory GoldPathPatrolConfig.fromDartDefines() {
    return GoldPathPatrolConfig.fromEnvironment({
      _ff1DeviceIdKey: const String.fromEnvironment(_ff1DeviceIdKey),
      _ff1TopicIdKey: const String.fromEnvironment(_ff1TopicIdKey),
      _ff1NameKey: const String.fromEnvironment(_ff1NameKey),
      _ff1RemoteIdKey: const String.fromEnvironment(_ff1RemoteIdKey),
      _ff1BranchNameKey: const String.fromEnvironment(_ff1BranchNameKey),
      _canaryChannelIdKey: const String.fromEnvironment(_canaryChannelIdKey),
      _canaryChannelTitleKey: const String.fromEnvironment(
        _canaryChannelTitleKey,
      ),
      _canaryWorkIdKey: const String.fromEnvironment(_canaryWorkIdKey),
      _canaryWorkTitleKey: const String.fromEnvironment(_canaryWorkTitleKey),
      _soakMinutesKey: const String.fromEnvironment(_soakMinutesKey),
      _soakSecondsKey: const String.fromEnvironment(_soakSecondsKey),
    });
  }

  /// Environment variable used for the injected FF1 device ID.
  static const String _ff1DeviceIdKey = 'GOLD_PATH_FF1_DEVICE_ID';

  /// Environment variable used for the injected FF1 topic ID.
  static const String _ff1TopicIdKey = 'GOLD_PATH_FF1_TOPIC_ID';

  static const String _ff1NameKey = 'GOLD_PATH_FF1_NAME';
  static const String _ff1RemoteIdKey = 'GOLD_PATH_FF1_REMOTE_ID';
  static const String _ff1BranchNameKey = 'GOLD_PATH_FF1_BRANCH_NAME';
  static const String _canaryChannelIdKey = 'GOLD_PATH_CANARY_CHANNEL_ID';
  static const String _canaryChannelTitleKey = 'GOLD_PATH_CANARY_CHANNEL_TITLE';
  static const String _canaryWorkIdKey = 'GOLD_PATH_CANARY_WORK_ID';
  static const String _canaryWorkTitleKey = 'GOLD_PATH_CANARY_WORK_TITLE';
  static const String _soakMinutesKey =
      'GOLD_PATH_SOAK_MINUTES'; // gitleaks:allow
  static const String _soakSecondsKey =
      'GOLD_PATH_SOAK_SECONDS'; // gitleaks:allow

  /// The real device ID shown on the FF1.
  final String ff1DeviceId;

  /// The relayer topic used for casting to the FF1.
  final String ff1TopicId;

  /// Friendly FF1 device name shown in app UI.
  final String ff1Name;

  /// Placeholder BLE remote ID. Cast uses topic ID, not BLE.
  final String ff1RemoteId;

  /// FF1 branch name stored in ObjectBox.
  final String ff1BranchName;

  /// Canary channel ID when a deterministic seed artifact is known.
  final String? canaryChannelId;

  /// Canary channel title used to assert presence in the Curated shelf.
  final String canaryChannelTitle;

  /// Canary work ID to target from the channel carousel when known.
  final String? canaryWorkId;

  /// Canary work title fallback when the work ID is not known.
  final String? canaryWorkTitle;

  /// Optional soak duration for CI or nightly runs.
  final Duration soakDuration;

  /// Builds the FF1 device injected into ObjectBox before the app starts.
  FF1Device toInjectedDevice() {
    return FF1Device(
      name: ff1Name,
      remoteId: ff1RemoteId,
      deviceId: ff1DeviceId,
      topicId: ff1TopicId,
      branchName: ff1BranchName,
    );
  }
}

extension on String {
  String? get nonEmptyOrNull => isEmpty ? null : this;
}
