import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Extension methods for Color
extension ColorExtension on ThemeData {
  /// Grey background color
  Color get auGreyBackground {
    final isLightMode =
        SchedulerBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.light;
    return isLightMode ? AppColor.auGreyBackground : AppColor.auGreyBackground;
  }
}
