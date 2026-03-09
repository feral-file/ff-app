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
///
/// Use [MainAppBar.preferred] when placing in [Scaffold.appBar] so height
/// adapts to [MediaQuery.textScalerOf] for accessibility (larger text).
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

  /// Returns a [PreferredSizeWidget] with height that adapts to text scaling.
  ///
  /// Use this for [Scaffold.appBar] so the app bar grows when the user
  /// enables larger text (Settings > Display > Font size).
  static PreferredSizeWidget preferred(
    BuildContext context, {
    String? backTitle,
    String? centeredTitle,
    Color? backgroundColor,
    List<Widget> actions = const [],
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final scaleFactor = textScaler.scale(1).clamp(1.0, 1.5);
    final height = LayoutConstants.space18 * scaleFactor;
    return PreferredSize(
      preferredSize: Size.fromHeight(height),
      child: MainAppBar(
        backTitle: backTitle,
        centeredTitle: centeredTitle,
        backgroundColor: backgroundColor,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = LayoutBuilder(
      builder: (context, constraints) {
        return SafeArea(
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: LayoutConstants.space3),
            color: backgroundColor ?? Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _BackButton(
                      title: backTitle ?? 'Index',
                      onTap: () => context.pop(),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: centeredTitle != null
                        ? Text(
                            centeredTitle!,
                            style: AppTypography.h4(context).white.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actions.isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              for (var i = 0; i < actions.length; i++) ...[
                                actions[i],
                                if (i < actions.length - 1)
                                  SizedBox(width: LayoutConstants.space2),
                              ],
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
  Size get preferredSize => const Size.fromHeight(69);
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
              Flexible(
                child: Text(
                  title,
                  style: AppTypography.body(context).copyWith(
                    color: PrimitivesTokens.colorsGrey,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
