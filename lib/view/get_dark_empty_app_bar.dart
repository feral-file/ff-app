import 'package:app/theme/app_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dark empty app bar (zero height, dark status bar).
/// Used by keyboard control screen to match old repo UI.
AppBar getDarkEmptyAppBar([Color? backgroundColor]) => AppBar(
  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarColor: backgroundColor ?? AppColor.auGreyBackground,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ),
  backgroundColor: backgroundColor ?? AppColor.primaryBlack,
  toolbarHeight: 0,
  shadowColor: Colors.transparent,
  elevation: 0,
  scrolledUnderElevation: 0,
);
