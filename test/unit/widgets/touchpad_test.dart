import 'package:app/app/providers/ff1_wifi_providers.dart';
import 'package:app/domain/models/ff1_device.dart';
import 'package:app/infra/ff1/wifi_control/ff1_wifi_control.dart';
import 'package:app/infra/ff1/wifi_protocol/ff1_wifi_messages.dart';
import 'package:app/infra/ff1/wifi_transport/ff1_wifi_transport.dart';
import 'package:app/widgets/ff_mouse_gesture_detector.dart';
import 'package:app/widgets/touchpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  group('TouchPad', () {
    testWidgets('routes tap, double tap, and long press to FF1 control', (
      tester,
    ) async {
      final control = _RecordingWifiControl();

      await tester.pumpWidget(_buildTestApp(control));
      final detector = tester.widget<FfMouseGestureDetector>(
        find.byType(FfMouseGestureDetector),
      );

      detector.onTap?.call();
      detector.onDoubleTap?.call();
      detector.onLongPress?.call();

      expect(control.tapCalls, 1);
      expect(control.doubleTapCalls, 1);
      expect(control.longPressCalls, 1);
    });

    testWidgets('routes move-only drag and click-and-drag with batching', (
      tester,
    ) async {
      final control = _RecordingWifiControl();

      await tester.pumpWidget(_buildTestApp(control));
      final center = tester.getCenter(find.byType(TouchPad));
      final detector = tester.widget<FfMouseGestureDetector>(
        find.byType(FfMouseGestureDetector),
      );

      final moveGesture = await tester.startGesture(center);
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        detector.onMove?.call(const Offset(4, 0));
      }
      await moveGesture.up();
      await tester.pump();

      expect(control.dragCalls, 1);
      expect(control.dragOffsets.single.length, 6);
      expect(control.clickAndDragCalls, 0);

      final clickAndDragGesture = await tester.startGesture(center);
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        detector.onClickAndDrag?.call(const Offset(3, 1));
      }
      await clickAndDragGesture.up();
      await tester.pump();

      expect(control.clickAndDragCalls, 1);
      expect(control.clickAndDragOffsets.single.length, 6);
    });

    testWidgets(
      'routes pinch zoom and keeps the session active until the last pointer lifts',
      (tester) async {
        final control = _RecordingWifiControl();

        await tester.pumpWidget(_buildTestApp(control));
        final center = tester.getCenter(find.byType(TouchPad));
        final detector = tester.widget<FfMouseGestureDetector>(
          find.byType(FfMouseGestureDetector),
        );

        final firstFinger = await tester.startGesture(
          center - const Offset(20, 0),
        );
        final secondFinger = await tester.startGesture(
          center + const Offset(20, 0),
        );
        await tester.pump();

        detector.onZoomGesture?.call(1.05);
        detector.onZoomGesture?.call(1.05);

        await firstFinger.up();
        await tester.pump();
        expect(control.zoomGestureCalls, 0);
        expect(control.dragCalls, 0);
        expect(control.clickAndDragCalls, 0);

        await secondFinger.up();
        await tester.pump();
        expect(control.zoomGestureCalls, 1);
        expect(control.zoomGestureScaleSteps.single, isNotEmpty);
      },
    );
  });
}

Widget _buildTestApp(_RecordingWifiControl control) {
  return ProviderScope(
    overrides: [
      ff1WifiControlProvider.overrideWithValue(control),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 240,
          height: 240,
          child: TouchPad(topicId: 'topic-1'),
        ),
      ),
    ),
  );
}

class _RecordingWifiControl extends FF1WifiControl {
  _RecordingWifiControl()
    : super(
        transport: _NoopWifiTransport(),
        restClient: null,
        logger: Logger('_RecordingWifiControl'),
      );

  int tapCalls = 0;
  int doubleTapCalls = 0;
  int longPressCalls = 0;
  int dragCalls = 0;
  int clickAndDragCalls = 0;
  int zoomGestureCalls = 0;
  final List<List<Offset>> dragOffsets = <List<Offset>>[];
  final List<List<Offset>> clickAndDragOffsets = <List<Offset>>[];
  final List<List<double>> zoomGestureScaleSteps = <List<double>>[];

  @override
  Future<FF1CommandResponse> tap({required String topicId}) async {
    tapCalls++;
    return FF1CommandResponse();
  }

  @override
  Future<FF1CommandResponse> doubleTap({required String topicId}) async {
    doubleTapCalls++;
    return FF1CommandResponse();
  }

  @override
  Future<FF1CommandResponse> longPress({required String topicId}) async {
    longPressCalls++;
    return FF1CommandResponse();
  }

  @override
  Future<FF1CommandResponse> drag({
    required String topicId,
    required List<Offset> cursorOffsets,
  }) async {
    dragCalls++;
    dragOffsets.add(List<Offset>.from(cursorOffsets));
    return FF1CommandResponse();
  }

  @override
  Future<FF1CommandResponse> clickAndDrag({
    required String topicId,
    required List<Offset> cursorOffsets,
  }) async {
    clickAndDragCalls++;
    clickAndDragOffsets.add(List<Offset>.from(cursorOffsets));
    return FF1CommandResponse();
  }

  @override
  Future<FF1CommandResponse> zoomGesture({
    required String topicId,
    required List<double> scaleSteps,
  }) async {
    zoomGestureCalls++;
    zoomGestureScaleSteps.add(List<double>.from(scaleSteps));
    return FF1CommandResponse();
  }
}

class _NoopWifiTransport implements FF1WifiTransport {
  final _notifications = BehaviorSubject<FF1NotificationMessage>();
  final _connections = BehaviorSubject<bool>();
  final _errors = BehaviorSubject<FF1WifiTransportError>();

  @override
  Stream<FF1NotificationMessage> get notificationStream => _notifications.stream;

  @override
  Stream<bool> get connectionStateStream => _connections.stream;

  @override
  Stream<FF1WifiTransportError> get errorStream => _errors.stream;

  @override
  bool get isConnected => false;

  @override
  bool get isConnecting => false;

  @override
  Future<bool> connect({
    required FF1Device device,
    required String userId,
    required String apiKey,
    bool forceReconnect = false,
  }) async {
    return true;
  }

  @override
  void pauseConnection() {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> sendCommand(Map<String, dynamic> command) async {}

  @override
  void dispose() {
    _notifications.close();
    _connections.close();
    _errors.close();
  }

  @override
  Future<void> disposeFuture() async {
    dispose();
  }
}
