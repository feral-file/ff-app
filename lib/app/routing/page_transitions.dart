import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Match CupertinoPageRoute: slide from right, parallax when covered.
// See: flutter/packages/flutter/lib/src/cupertino/route.dart
const Duration _kCupertinoTransitionDuration = Duration(milliseconds: 500);

/// Offset from offscreen right to fully on screen (primary animation).
final Animatable<Offset> _kRightMiddleTween = Tween<Offset>(
  begin: const Offset(1, 0),
  end: Offset.zero,
);

/// Offset from on screen to 1/3 offscreen left (parallax when covered).
final Animatable<Offset> _kMiddleLeftTween = Tween<Offset>(
  begin: Offset.zero,
  end: const Offset(-1 / 3, 0),
);

/// Builds a [CustomTransitionPage] with iOS-standard transition like
/// [CupertinoPageRoute]: new page slides in from the right, underlying page
/// shifts left in parallax when covered.
///
/// Use as [GoRoute.pageBuilder] for push/pop navigation.
Page<void> buildCupertinoTransitionPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _kCupertinoTransitionDuration,
    reverseTransitionDuration: _kCupertinoTransitionDuration,
    transitionsBuilder: (
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      final TextDirection textDirection = Directionality.of(context);
      final Animation<Offset> primaryPosition = CurvedAnimation(
        parent: animation,
        curve: Curves.fastEaseInToSlowEaseOut,
        reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
      ).drive(_kRightMiddleTween);
      final Animation<Offset> secondaryPosition = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.linearToEaseOut,
        reverseCurve: Curves.easeInToLinear,
      ).drive(_kMiddleLeftTween);
      return SlideTransition(
        position: secondaryPosition,
        textDirection: textDirection,
        transformHitTests: false,
        child: SlideTransition(
          position: primaryPosition,
          textDirection: textDirection,
          child: child,
        ),
      );
    },
  );
}
