import 'dart:io';

import 'package:app/infra/logging/app_logger.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Opens the user's email client with a prefilled support draft.
class SupportEmailService {
  /// Creates a support email composer service.
  SupportEmailService({Logger? logger})
    : _logger = logger ?? Logger('SupportEmailService');

  final Logger _logger;

  /// Compose an email to support with optional attached app log file.
  Future<void> composeSupportEmail({
    required String recipient,
  }) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final attachmentPaths = <String>[];
    final logFile = AppLogger.currentLogFile;
    if (logFile != null && logFile.existsSync()) {
      attachmentPaths.add(logFile.path);
    } else {
      _logger.warning('No log file found to attach to support email.');
    }

    final email = Email(
      recipients: [recipient],
      subject: 'Feral File support request',
      body:
          '''
Please describe the issue you are seeing:


App version: ${packageInfo.version} (${packageInfo.buildNumber})
Platform: ${Platform.operatingSystem}
''',
      attachmentPaths: attachmentPaths,
    );

    await FlutterEmailSender.send(email);
  }
}
