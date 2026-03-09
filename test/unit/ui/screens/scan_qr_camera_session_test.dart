import 'dart:async';

import 'package:app/ui/screens/scan_qr_camera_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScanQrCameraSession', () {
    test('deduplicates consecutive resume requests', () async {
      var startCalls = 0;
      var stopCalls = 0;
      final session = ScanQrCameraSession(
        startCamera: () async {
          startCalls++;
        },
        stopCamera: () async {
          stopCalls++;
        },
      );

      await session.resume();
      await session.resume();

      expect(startCalls, 1);
      expect(stopCalls, 0);
    });

    test('serializes start then stop when requests race', () async {
      final sequence = <String>[];
      final startCompleter = Completer<void>();

      final session = ScanQrCameraSession(
        startCamera: () async {
          sequence.add('start-begin');
          await startCompleter.future;
          sequence.add('start-end');
        },
        stopCamera: () async {
          sequence.add('stop');
        },
      );

      final pendingResume = session.resume();
      final pendingPause = session.pause();

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(sequence, ['start-begin']);

      startCompleter.complete();
      await pendingResume;
      await pendingPause;

      expect(sequence, ['start-begin', 'start-end', 'stop']);
    });
  });
}
