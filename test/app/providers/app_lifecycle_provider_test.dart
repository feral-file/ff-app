import 'package:app/app/providers/app_lifecycle_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldCheckpointForLifecycleState', () {
    test('returns true only for paused and detached', () {
      expect(
        shouldCheckpointForLifecycleState(AppLifecycleState.resumed),
        isFalse,
      );
      expect(
        shouldCheckpointForLifecycleState(AppLifecycleState.inactive),
        isFalse,
      );
      expect(
        shouldCheckpointForLifecycleState(AppLifecycleState.hidden),
        isFalse,
      );
      expect(
        shouldCheckpointForLifecycleState(AppLifecycleState.paused),
        isTrue,
      );
      expect(
        shouldCheckpointForLifecycleState(AppLifecycleState.detached),
        isTrue,
      );
    });
  });
}
