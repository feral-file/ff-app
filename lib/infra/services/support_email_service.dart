import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/database/ff1_bluetooth_device_service.dart';
import 'package:app/infra/logging/app_logger.dart';
import 'package:app/infra/services/device_info_service.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the user's email client with a prefilled support draft.
///
/// Email subject and body match the old Feral File app format for consistency
/// with support workflows.
class SupportEmailService {
  /// Creates a support email composer service.
  SupportEmailService({
    required DeviceInfoService deviceInfoService,
    FF1BluetoothDeviceService? ff1DeviceService,
    Logger? logger,
  })  : _deviceInfoService = deviceInfoService,
        _ff1DeviceService = ff1DeviceService,
        _logger = logger ?? Logger('SupportEmailService');

  final DeviceInfoService _deviceInfoService;
  final FF1BluetoothDeviceService? _ff1DeviceService;
  final Logger _logger;

  /// Compose an email to support with optional attached app log file.
  ///
  /// Subject and body match the old repo format. Uses [FlutterEmailSender]
  /// first (supports attachments). If that fails, falls back to [url_launcher]
  /// with a mailto: URL (no attachments).
  Future<void> composeSupportEmail({
    required String recipient,
  }) async {
    await _deviceInfoService.init();

    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;

    final attachmentPaths = <String>[];
    final logFile = AppLogger.currentLogFile;
    if (logFile != null && logFile.existsSync()) {
      attachmentPaths.add(logFile.path);
    } else {
      _logger.warning('No log file found to attach to support email.');
    }
    final attachLogs = attachmentPaths.isNotEmpty;

    final deviceName = _deviceInfoService.deviceName;
    final osName = _deviceInfoService.deviceOSName;
    final osVersion = _deviceInfoService.deviceOSVersion;
    final userId = _deviceInfoService.deviceId;

    final allDevices = _ff1DeviceService?.getAllDevices() ?? <FF1Device>[];
    final castingDevice = _ff1DeviceService?.getActiveDevice();
    final castingDeviceId = castingDevice?.deviceId;
    final ff1DeviceId = castingDevice?.name ?? 'unknown (not connected)';

    const shortSummary = 'Support request';
    final subject =
        'Support: $shortSummary — App $appVersion ($buildNumber) — Device $ff1DeviceId';

    final yesNoLog = attachLogs ? 'yes' : 'no';

    final buffer = StringBuffer()
      ..writeln('What happened? (1 sentence)')
      ..writeln('-')
      ..writeln()
      ..writeln(
        'If you can, attach a screenshot or short screen recording to this email.',
      )
      ..writeln()
      ..writeln('I was trying to: (pick one)')
      ..writeln('- Setup FF1 Wi-Fi')
      ..writeln('- Connect phone → FF1')
      ..writeln('- Play an artwork')
      ..writeln('- Play a playlist')
      ..writeln('- Play My Collection')
      ..writeln('- Other:')
      ..writeln()
      ..writeln('Auto details')
      ..writeln('- App: $appVersion ($buildNumber)')
      ..writeln('- Phone: $deviceName • $osName $osVersion');

    if (allDevices.isNotEmpty) {
      buffer.writeln('- FF1 devices:');
      for (final device in allDevices) {
        final isSelected = device.deviceId == castingDeviceId;
        final marker = isSelected ? '[selected]' : '-';
        buffer.writeln('     - ${device.deviceId} $marker');
      }
    } else {
      buffer.writeln('- FF1 devices: none (not paired)');
    }

    buffer
      ..writeln('- User ID: $userId')
      ..writeln('- Debug log attached: $yesNoLog')
      ..writeln();

    final body = buffer.toString();

    final email = Email(
      recipients: [recipient],
      subject: subject,
      body: body,
      attachmentPaths: attachmentPaths,
    );

    try {
      await FlutterEmailSender.send(email);
    } on Exception catch (e) {
      _logger.warning('FlutterEmailSender failed: $e. Falling back to mailto.');
      await _openMailtoFallback(
        recipient: recipient,
        subject: subject,
        body: body,
      );
    }
  }

  /// Fallback: open mailto: URL when native email composer is unavailable.
  /// Does not support attachments; user can attach manually if needed.
  Future<void> _openMailtoFallback({
    required String recipient,
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: recipient,
      queryParameters: {'subject': subject, 'body': body},
    );
    if (await launchUrl(uri)) {
      return;
    }
    throw Exception('Could not open email client.');
  }
}
