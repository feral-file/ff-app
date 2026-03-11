import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Extension methods for ThemeData
extension ThemeExtension on ThemeData {
  /// Grey background color
  Color get auGreyBackground {
    final isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.light;
    return isLightMode ? AppColor.auGreyBackground : AppColor.auGreyBackground;
  }
}

/// Extension methods for Color
extension ColorExtension on Color {
  /// Convert the color to a hex string
  String toHexString() {
    return '#${toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }
}
