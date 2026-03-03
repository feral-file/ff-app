import 'dart:io';

import 'package:app/domain/models/version_info.dart';
import 'package:app/domain/utils/version_utils.dart';
import 'package:app/infra/services/remote_config_service.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Checks app version against remote config and opens store for update.
class ForceUpdateService {
  /// Creates a [ForceUpdateService].
  ForceUpdateService({
    required RemoteConfigService remoteConfigService,
    PackageInfo? packageInfo,
  }) : _remoteConfigService = remoteConfigService,
       _packageInfo = packageInfo;

  final RemoteConfigService _remoteConfigService;
  final PackageInfo? _packageInfo;

  /// Checks if force update is required by reading from cached remote config.
  ///
  /// Uses [RemoteConfigService.get] (cache-only). Call [RemoteConfigService.fetchAndPersist]
  /// before this to ensure cache is fresh.
  /// Returns [VersionInfo] if current version < required version, null otherwise.
  /// Skips check when [kDebugMode] is true (unless [forceCheck] is true for tests).
  Future<VersionInfo?> checkForUpdate({bool forceCheck = false}) async {
    if (kDebugMode && !forceCheck) return null;

    final platformKey = Platform.isIOS ? 'ios' : 'android';
    final requiredVersion = await _remoteConfigService.get<String>(
      'app_update.$platformKey.required_version',
      '',
    );
    final link = await _remoteConfigService.get<String>(
      'app_update.$platformKey.link',
      '',
    );

    if (requiredVersion.isEmpty || link.isEmpty) return null;

    final packageInfo = _packageInfo ?? await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;
    final fullCurrent = buildNumber.isNotEmpty
        ? '$currentVersion($buildNumber)'
        : currentVersion;

    if (compareVersion(requiredVersion, fullCurrent) > 0) {
      return VersionInfo(requiredVersion: requiredVersion, link: link);
    }

    return null;
  }

  /// Opens the store URL for update.
  Future<void> openStoreUrl(String link) async {
    final uri = Uri.tryParse(link);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
