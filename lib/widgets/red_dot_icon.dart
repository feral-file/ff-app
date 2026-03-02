import 'package:flutter/material.dart';

/// Red dot icon.
class RedDotIcon extends StatelessWidget {
  /// Constructor
  const RedDotIcon({
    required this.icon,
    this.padding,
    this.withRedDot = true,
    super.key,
  });

  /// Icon.
  final Widget icon;

  /// Padding.
  final EdgeInsetsGeometry? padding;

  /// Whether to show red dot.
  final bool withRedDot;

  /// Red dot icon.
  Widget redDotIcon() => Container(
    width: 10,
    height: 10,
    decoration: const BoxDecoration(
      color: Colors.red,
      shape: BoxShape.circle,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return withRedDot
        ? Stack(
            alignment: Alignment.topRight,
            children: [
              Padding(
                padding: padding ?? const EdgeInsets.only(right: 5),
                child: icon,
              ),
              redDotIcon(),
            ],
          )
        : icon;
  }
}
