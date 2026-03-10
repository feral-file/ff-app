import 'dart:convert';

import 'package:app/infra/logging/structured_log_context.dart';
import 'package:app/infra/logging/structured_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  group('StructuredLogger', () {
    setUp(() {
      hierarchicalLoggingEnabled = true;
      Logger.root.level = Level.ALL;
    });

    test('emits category-prefixed message with structured metadata', () {
      final records = <LogRecord>[];
      final logger = Logger('StructuredLoggerTest')
        ..onRecord.listen(records.add);

      StructuredLogContext.updateCurrentRoute('/ff1-device-picker');

      AppStructuredLog.forLogger(logger).info(
        category: LogCategory.ui,
        event: 'ui_action',
        message: 'tapped scan_qr_button',
        payload: {'action': 'scan_qr_button'},
      );

      expect(records, isNotEmpty);
      final message = records.single.message;
      expect(message.startsWith('[ui] tapped scan_qr_button | meta='), isTrue);

      final metaJson = message.split('| meta=').last.trim();
      final meta = jsonDecode(metaJson) as Map<String, dynamic>;
      expect(meta['category'], 'ui');
      expect(meta['event'], 'ui_action');
      expect(meta['route'], '/ff1-device-picker');
      expect(meta['sessionId'], isNotEmpty);
    });

    test('propagates flow id from runFlow zone context', () async {
      final records = <LogRecord>[];
      final logger = Logger('StructuredLoggerFlowTest')
        ..onRecord.listen(records.add);

      final structured = AppStructuredLog.forLogger(logger);
      await StructuredLogContext.runFlow(
        flowId: 'flow-123',
        action: () async {
          structured.info(
            category: LogCategory.domain,
            event: 'flow_step',
            message: 'step executed',
          );
        },
      );

      final message = records.single.message;
      final metaJson = message.split('| meta=').last.trim();
      final meta = jsonDecode(metaJson) as Map<String, dynamic>;
      expect(meta['flowId'], 'flow-123');
    });

    test(
      'does not leak flow id into non-error logs after flow completes',
      () async {
        final records = <LogRecord>[];
        final logger = Logger('StructuredLoggerNoLeakTest')
          ..onRecord.listen(records.add);

        final structured = AppStructuredLog.forLogger(logger);
        await StructuredLogContext.runFlow(
          flowId: 'flow-123',
          action: () async {
            structured.info(
              category: LogCategory.domain,
              event: 'flow_step',
              message: 'step executed',
            );
          },
        );

        structured.info(
          category: LogCategory.route,
          event: 'route_changed',
          message: 'viewed HomeIndexPage',
        );

        final secondMessage = records[1].message;
        final secondMetaJson = secondMessage.split('| meta=').last.trim();
        final secondMeta = jsonDecode(secondMetaJson) as Map<String, dynamic>;
        expect(secondMeta.containsKey('flowId'), isFalse);
      },
    );
  });
}
