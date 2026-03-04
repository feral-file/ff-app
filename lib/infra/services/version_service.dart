import 'dart:io';

import 'package:app/app/routing/app_navigator_key.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/domain/utils/version_utils.dart';
import 'package:app/infra/api/pubdoc_api.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

const _kAppStoreUrl =
    'https://apps.apple.com/us/app/feral-file-controller/id6755812386';
const _kPlayStoreUrl =
    'https://play.google.com/store/apps/details?id=com.feralfile.app';

/// Result of comparing mobile app version with FF1 device version.
enum VersionCompatibilityResult {
  /// The app and device are compatible.
  compatible,

  /// The app needs to be updated.
  needUpdateApp,

  /// The device needs to be updated.
  needUpdateDevice,

  /// Compatibility could not be determined (data missing or fetch failed).
  unknown,

  /// The device was not found.
  deviceNotFound
  ;

  /// Whether the result represents a compatible state.
  bool get isValid =>
      this != VersionCompatibilityResult.needUpdateApp &&
      this != VersionCompatibilityResult.needUpdateDevice;
}

/// Service responsible for checking version compatibility between
/// the mobile app and FF1 device firmware.
class VersionService {
  /// Constructor
  ///
  /// [navigatorKey] is used to resolve the current [BuildContext] for dialogs
  /// without requiring callers to pass one. Pass [appNavigatorKey] in
  /// production. When `null` (e.g. in unit tests), dialog display is skipped
  /// and only the [VersionCompatibilityResult] is returned.
  ///
  /// [packageInfoLoader] is injected to allow test overrides.
  /// Defaults to [PackageInfo.fromPlatform] in production.
  VersionService({
    required PubDocApi pubDocApi,
    GlobalKey<NavigatorState>? navigatorKey,
    Logger? logger,
    String? platformOverride,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : _pubDocApi = pubDocApi,
       _navigatorKey = navigatorKey,
       _log = logger ?? Logger('VersionService'),
       _platformOverride = platformOverride,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  final PubDocApi _pubDocApi;
  // Nullable: when null (unit tests) dialog display is skipped entirely.
  final GlobalKey<NavigatorState>? _navigatorKey;
  final Logger _log;
  final String? _platformOverride;
  final Future<PackageInfo> Function() _packageInfoLoader;

  PackageInfo? _packageInfo;

  /// Gets the package info, caching the result after the first call.
  Future<PackageInfo> getPackageInfo() async {
    _packageInfo ??= await _packageInfoLoader();
    return _packageInfo!;
  }

  /// Checks whether the current app version is compatible with a given
  /// FF1 firmware [deviceVersion] on [branchName].
  ///
  /// On incompatibility, automatically shows the appropriate dialog using the
  /// context resolved from [_navigatorKey]:
  /// - `needUpdateApp` → [showVersionNotCompatibleDialog]
  /// - `needUpdateDevice` → [showDeviceNotCompatibleDialog]
  ///   (only when [requiredDeviceUpdate] is `true`)
  ///
  /// [deviceName] is used in the dialog text; defaults to `'FF1'`.
  ///
  /// Returns a [VersionCompatibilityResult] describing whether the app
  /// needs an update, the device needs an update, or they are compatible.
  Future<VersionCompatibilityResult> checkDeviceVersionCompatibility({
    required String branchName,
    required String deviceVersion,
    bool requiredDeviceUpdate = false,
    String deviceName = 'FF1',
  }) async {
    final compatibilityData = await _pubDocApi.getVersionCompatibility();
    if (compatibilityData.isEmpty) {
      _log.info('No compatibility version found for branch: $branchName');
      return VersionCompatibilityResult.unknown;
    }

    late VersionCompatibilityResult result;
    try {
      final packageInfo = await getPackageInfo();
      final fullAppVersion =
          '${packageInfo.version}(${packageInfo.buildNumber})';

      _log
        ..info('Checking app version compatibility:')
        ..info('Branch: $branchName')
        ..info('Device version: $deviceVersion')
        ..info('App version: $fullAppVersion');

      result = _checkCompatibilityForVersions(
        data: compatibilityData,
        branchName: branchName,
        deviceVersion: deviceVersion,
        appVersionWithBuild: fullAppVersion,
      );
    } on Exception catch (error, stackTrace) {
      _log.warning(
        'Error checking app/device version compatibility.',
        error,
        stackTrace,
      );
      return VersionCompatibilityResult.unknown;
    }

    // Show the appropriate dialog when a navigator key is available.
    // Skipped when _navigatorKey is null (unit-test environments).
    // The dialog blocks until dismissed so the caller can act on the
    // returned result immediately after.
    if (_navigatorKey != null) {
      switch (result) {
        case VersionCompatibilityResult.needUpdateApp:
          await showVersionNotCompatibleDialog(deviceName);
        case VersionCompatibilityResult.needUpdateDevice:
          if (requiredDeviceUpdate) {
            await showDeviceNotCompatibleDialog(deviceName);
          }
        case VersionCompatibilityResult.compatible:
        case VersionCompatibilityResult.unknown:
        case VersionCompatibilityResult.deviceNotFound:
          break;
      }
    }

    return result;
  }

  VersionCompatibilityResult _checkCompatibilityForVersions({
    required Map<String, dynamic> data,
    required String branchName,
    required String deviceVersion,
    required String appVersionWithBuild,
  }) {
    final branchData = data[branchName];
    if (branchData is! Map<String, dynamic>) {
      _log.info('No compatibility data found for branch: $branchName');
      return VersionCompatibilityResult.unknown;
    }

    var versionInfo = branchData[deviceVersion];
    if (versionInfo == null) {
      _log.info(
        'No compatibility data for device version: $deviceVersion, '
        'trying to find latest compatible version.',
      );
      final latestCompatibleVersion = _findLatestCompatibleVersion(
        branchData,
        deviceVersion,
      );
      if (latestCompatibleVersion == null) {
        _log.info(
          'No compatible version found for device version: $deviceVersion',
        );
        return VersionCompatibilityResult.unknown;
      }
      versionInfo = branchData[latestCompatibleVersion];
      _log.info(
        'Using compatibility data from version: $latestCompatibleVersion',
      );
    } else {
      _log.info(
        'Found compatibility data for device version: $deviceVersion',
      );
    }

    String? minVersion;
    String? maxVersion;

    final platform = _currentPlatformTag;

    if (platform == 'android') {
      minVersion = versionInfo['min_android_version'] as String?;
      maxVersion = versionInfo['max_android_version'] as String?;
    } else if (platform == 'ios') {
      minVersion = versionInfo['min_ios_version'] as String?;
      maxVersion = versionInfo['max_ios_version'] as String?;
    }

    if (minVersion != null &&
        compareVersion(appVersionWithBuild, minVersion) < 0) {
      return VersionCompatibilityResult.needUpdateApp;
    }

    if (maxVersion != null &&
        compareVersion(appVersionWithBuild, maxVersion) > 0) {
      return VersionCompatibilityResult.needUpdateDevice;
    }

    return VersionCompatibilityResult.compatible;
  }

  String? get _currentPlatformTag {
    if (_platformOverride != null) {
      return _platformOverride;
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    return null;
  }

  /// Opens the platform-appropriate app store listing so the user can update.
  ///
  /// Uses [_kAppStoreUrl] on iOS and [_kPlayStoreUrl] on Android.
  Future<void> openLatestVersion() async {
    final url = Platform.isIOS ? _kAppStoreUrl : _kPlayStoreUrl;
    final uri = Uri.parse(url);
    if (!uri.hasScheme) return;

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException catch (_) {
      // No Activity found (e.g. emulator without Play Store) — fail silently
    }
  }

  /// Shows a non-dismissible dialog informing the user that the current app
  /// version is not compatible with [deviceName] and prompting an app update.
  ///
  /// Resolves the current [BuildContext] from [_navigatorKey]. Returns early
  /// if the context is unavailable or the widget is no longer mounted.
  /// Reads the current package version from [getPackageInfo] to include in
  /// the message. Tapping "Update now" calls [openLatestVersion].
  Future<void> showVersionNotCompatibleDialog(String deviceName) async {
    var context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    final packageInfo = await getPackageInfo();
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;

    // Re-check after the async gap above.
    context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    await UIHelper.showDialog<void>(
      context,
      'App update required',
      PopScope(
        canPop: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: AppTypography.body(context).white,
                children: [
                  const TextSpan(text: 'App version '),
                  TextSpan(
                    text: '$version ($buildNumber)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' is not compatible with your '),
                  TextSpan(
                    text: deviceName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text:
                        '. Please update the app to continue '
                        'using your device.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryAsyncButton(
              text: 'Update now',
              onTap: openLatestVersion,
            ),
          ],
        ),
      ),
    );
  }

  /// Shows a non-dismissible dialog informing the user that [deviceName] is
  /// running firmware that is too old for this app version.
  ///
  /// Resolves the current [BuildContext] from [_navigatorKey]. Returns early
  /// if the context is unavailable or the widget is no longer mounted.
  Future<void> showDeviceNotCompatibleDialog(String deviceName) async {
    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    await UIHelper.showDialog<void>(
      context,
      'FF1 software update needed',
      PopScope(
        canPop: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: AppTypography.body(context).white,
                children: [
                  const TextSpan(text: 'Your '),
                  TextSpan(
                    text: deviceName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text:
                        ' is running an older software version. '
                        'Please update your FF1 to ensure full functionality.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _findLatestCompatibleVersion(
    Map<String, dynamic> branchData,
    String deviceVersion,
  ) {
    String? latestVersion;

    for (final version in branchData.keys) {
      if (compareVersion(version, deviceVersion) >= 0) {
        continue;
      }
      if (latestVersion == null || compareVersion(version, latestVersion) > 0) {
        latestVersion = version;
      }
    }

    return latestVersion;
  }
}
