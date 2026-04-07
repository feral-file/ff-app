import 'package:app/widgets/device_configuration/ffp_slider_controls.dart';
import 'package:app/widgets/device_configuration/icon_slider_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('FFP brightness control wires the zero-toggle icon action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FfpBrightnessControl(
            value: 40,
            onChanged: _noop,
          ),
        ),
      ),
    );

    final widget = tester.widget<IconSliderControl>(
      find.byType(IconSliderControl),
    );
    expect(widget.onIconTap, isNotNull);
  });

  testWidgets('FFP contrast control wires the zero-toggle icon action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FfpContrastControl(
            value: 60,
            onChanged: _noop,
          ),
        ),
      ),
    );

    final widget = tester.widget<IconSliderControl>(
      find.byType(IconSliderControl),
    );
    expect(widget.onIconTap, isNotNull);
  });
}

void _noop(double value) {}
