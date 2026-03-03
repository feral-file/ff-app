import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// App bar for setup pages
class SetupAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates a SetupAppBar.
  const SetupAppBar({
    super.key,
    this.title = '',
    this.titleStyle,
    this.actions = const [],
    this.onBack,
    this.backgroundColor = PrimitivesTokens.colorsDarkGrey,
    this.titleColor = PrimitivesTokens.colorsWhite,
    this.statusBarColor,
    this.surfaceTintColor,
    this.withDivider = true,
    this.isDarkMode = true,
    this.hasBackButton = true,
  });

  /// Title of the app bar.
  final String title;

  /// Style of the title.
  final TextStyle? titleStyle;

  /// Actions of the app bar.
  final List<Widget>? actions;

  /// Callback when the back button is pressed.
  final VoidCallback? onBack;

  /// Background color of the app bar.
  final Color backgroundColor;

  /// Color of the title.
  final Color titleColor;

  /// Status bar color of the app bar.
  final Color? statusBarColor;

  /// Surface tint color of the app bar.
  final Color? surfaceTintColor;

  /// Whether to show a divider.
  final bool withDivider;

  /// Whether to use dark mode.
  final bool isDarkMode;

  /// Whether to show a back button.
  final bool hasBackButton;

  /// Back button.
  Widget backButton(
    BuildContext context, {
    required VoidCallback onBack,
    Color? color,
  }) => Semantics(
    label: 'Back Button',
    child: IconButton(
      constraints: const BoxConstraints(
        maxWidth: 44,
        maxHeight: 44,
        minWidth: 44,
        minHeight: 44,
      ),
      onPressed: onBack,
      icon: Padding(
        padding: const EdgeInsets.all(10),
        child: SvgPicture.asset(
          'assets/images/icon_back.svg',
          width: 24,
          height: 24,
          colorFilter: color != null
              ? ColorFilter.mode(color, BlendMode.srcIn)
              : null,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: statusBarColor ?? backgroundColor,
        statusBarIconBrightness: isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      ),
      centerTitle: true,
      scrolledUnderElevation: 0,
      toolbarHeight: 54,
      leading: hasBackButton
          ? backButton(
              context,
              onBack: () {
                if (onBack != null) {
                  onBack!();
                } else {
                  context.pop();
                  // If can't pop, do nothing (e.g., we're at the first screen)
                }
              },
              color: titleColor,
            )
          : const SizedBox(),
      leadingWidth: 56,
      automaticallyImplyLeading: false,
      title: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: titleStyle ?? AppTypography.body(context).white,
        textAlign: TextAlign.center,
      ),
      actions: [
        ...actions ?? [],
      ],
      backgroundColor: backgroundColor,
      surfaceTintColor: surfaceTintColor ?? Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      bottom: withDivider
          ? const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(
                height: 1,
                color: PrimitivesTokens.colorsBlack,
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
