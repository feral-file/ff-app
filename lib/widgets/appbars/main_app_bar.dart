import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// Main app bar for detail screens (playlist, channel, work, etc.).
/// Adapted from Feral File old repo MainAppBar.
/// Has back button with optional label, optional centered title, and actions.
class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a MainAppBar.
  const MainAppBar({
    super.key,
    this.backTitle,
    this.centeredTitle,
    this.backgroundColor,
    this.actions = const [],
  });

  /// Label shown next to the back arrow (e.g. 'Index', 'Playlists').
  final String? backTitle;

  /// Optional centered title in the app bar.
  final String? centeredTitle;

  /// Background color; defaults to transparent.
  final Color? backgroundColor;

  /// Optional action widgets on the right.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final appBar = SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: LayoutConstants.space3,
          vertical: LayoutConstants.space5,
        ),
        color: backgroundColor ?? Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: _BackButton(
                title: backTitle ?? 'Index',
                onTap: () => context.pop(),
              ),
            ),
            if (centeredTitle != null)
              Center(
                child: Text(
                  centeredTitle!,
                  style: AppTypography.h3(context).white.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (actions.isNotEmpty)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      actions[i],
                      if (i < actions.length - 1)
                        SizedBox(width: LayoutConstants.space2),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: backgroundColor ?? PrimitivesTokens.colorsDarkGrey,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: appBar,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(LayoutConstants.space18);
}

class _BackButton extends StatelessWidget {
  const _BackButton({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Back Button',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: BoxConstraints(
            minWidth: LayoutConstants.minTouchTarget,
            minHeight: LayoutConstants.minTouchTarget,
          ),
          alignment: Alignment.centerLeft,
          color: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: LayoutConstants.space2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/images/icon_back.svg',
                width: LayoutConstants.iconSizeDefault,
                height: LayoutConstants.iconSizeDefault,
                colorFilter: const ColorFilter.mode(
                  PrimitivesTokens.colorsGrey,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: LayoutConstants.space3),
              Text(
                title,
                style: AppTypography.body(context).copyWith(
                  color: PrimitivesTokens.colorsGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
