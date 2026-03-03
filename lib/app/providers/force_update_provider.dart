import 'package:app/domain/models/version_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for force update: non-null when user must update to continue.
final forceUpdateProvider =
    NotifierProvider<ForceUpdateNotifier, VersionInfo?>(ForceUpdateNotifier.new);

/// Notifier for force update state.
class ForceUpdateNotifier extends Notifier<VersionInfo?> {
  @override
  VersionInfo? build() => null;

  /// Sets the required version info when force update is needed.
  void setRequired(VersionInfo versionInfo) {
    state = versionInfo;
  }
}
