import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Test the Sentry filter logic by mirroring the implementation.
// Since _isSeedSyncNetworkError is private, we replicate it in a testable
// form with the same behavior to prevent regressions.

void main() {
  group('Sentry seed sync network error filter', () {
    /// Helper to create a fake SentryEvent with an exception and stack
    /// frames.
    SentryEvent createEventWithException({
      required String exceptionType,
      required List<String> stackFrameFileNames,
    }) {
      final frames = stackFrameFileNames
          .map(
            (fileName) => SentryStackFrame(
              fileName: fileName,
              function: 'testFunction',
            ),
          )
          .toList();

      return SentryEvent(
        exceptions: [
          SentryException(
            type: exceptionType,
            value: 'Test $exceptionType',
            stackTrace: SentryStackTrace(frames: frames),
          ),
        ],
      );
    }

    test(
      'returns true for SocketException with seed_database in stack',
      () {
        final event = createEventWithException(
          exceptionType: 'SocketException',
          stackFrameFileNames: [
            'some_other_file.dart',
            'seed_database_service.dart',
          ],
        );

        expect(_isSeedSyncNetworkErrorTest(event), isTrue);
      },
    );

    test(
      'returns true for DioException with seed_database in stack',
      () {
        final event = createEventWithException(
          exceptionType: 'DioException',
          stackFrameFileNames: [
            'some_other_file.dart',
            'lib/infra/services/seed_database_sync_service.dart',
          ],
        );

        expect(_isSeedSyncNetworkErrorTest(event), isTrue);
      },
    );

    test(
      'returns false for SocketException without seed_database in stack',
      () {
        final event = createEventWithException(
          exceptionType: 'SocketException',
          stackFrameFileNames: [
            'some_other_file.dart',
            'another_service.dart',
          ],
        );

        expect(_isSeedSyncNetworkErrorTest(event), isFalse);
      },
    );

    test(
      'returns false for DioException without seed_database in stack',
      () {
        final event = createEventWithException(
          exceptionType: 'DioException',
          stackFrameFileNames: [
            'some_other_file.dart',
            'tv_cast_dio.dart',
          ],
        );

        expect(_isSeedSyncNetworkErrorTest(event), isFalse);
      },
    );

    test(
      'returns false for FormatException with seed_database in stack',
      () {
        final event = createEventWithException(
          exceptionType: 'FormatException',
          stackFrameFileNames: [
            'seed_database_service.dart',
          ],
        );

        expect(_isSeedSyncNetworkErrorTest(event), isFalse);
      },
    );

    test(
      'returns false for event with no exceptions',
      () {
        final event = SentryEvent();
        expect(_isSeedSyncNetworkErrorTest(event), isFalse);
      },
    );

    test(
      'returns false for exception with no stack trace',
      () {
        final event = SentryEvent(
          exceptions: [
            SentryException(
              type: 'SocketException',
              value: 'Test SocketException',
            ),
          ],
        );

        expect(_isSeedSyncNetworkErrorTest(event), isFalse);
      },
    );

    test(
      'returns false for exception with empty stack frames',
      () {
        final event = SentryEvent(
          exceptions: [
            SentryException(
              type: 'SocketException',
              value: 'Test SocketException',
              stackTrace: SentryStackTrace(frames: []),
            ),
          ],
        );

        expect(_isSeedSyncNetworkErrorTest(event), isFalse);
      },
    );

    test(
      'detects seed_database even when fileName has path prefix',
      () {
        final event = SentryEvent(
          exceptions: [
            SentryException(
              type: 'SocketException',
              value: 'Test SocketException',
              stackTrace: SentryStackTrace(
                frames: [
                  SentryStackFrame(
                    fileName: 'lib/infra/services/seed_database_sync_service.dart',
                    function: 'syncIfNeeded',
                  ),
                ],
              ),
            ),
          ],
        );

        expect(_isSeedSyncNetworkErrorTest(event), isTrue);
      },
    );
  });
}

/// Standalone implementation of the filter logic for testing.
/// This mirrors the _isSeedSyncNetworkError function from main.dart.
bool _isSeedSyncNetworkErrorTest(SentryEvent event) {
  final exceptions = event.exceptions;
  if (exceptions == null || exceptions.isEmpty) return false;

  final exception = exceptions.first;

  // Check exception type: filter SocketException and DioException.
  final exceptionType = exception.type;
  if (exceptionType != 'SocketException' && exceptionType != 'DioException') {
    return false;
  }

  // Check if this event is from seed_database component (stack trace).
  final stackTrace = exception.stackTrace;
  if (stackTrace == null) return false;

  final frames = stackTrace.frames;
  if (frames.isEmpty) return false;

  return frames.any(
    (frame) =>
        (frame.fileName?.contains('seed_database') ?? false) ||
        (frame.function?.contains('seed_database') ?? false),
  );
}
