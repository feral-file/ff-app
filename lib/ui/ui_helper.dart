import 'dart:async';

import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/domain/models/wallet_address.dart';
import 'package:app/infra/services/support_email_service.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/buttons/outline_button.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:app/widgets/loading_indicator.dart';
import 'package:app/widgets/top_right_rectangle_clipper.dart';
import 'package:app/widgets/work_grid_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// UI helpers for reusable UI patterns.
///
/// Note: This is UI-layer only. It must not include transport/protocol logic.
class UIHelper {
  UIHelper._();

  static String currentDialogTitle = '';

  /// Ignore back layer pop up route name
  static const String ignoreBackLayerPopUpRouteName = 'popUp.ignoreBackLayer';

  /// Builds a DP-1 works grid as a sliver (domain [PlaylistItem] only).
  static SliverGrid worksSliverGrid({
    required List<PlaylistItem> works,
    required void Function(PlaylistItem item) onItemTap,
  }) {
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: LayoutConstants.worksGridChildAspectRatio,
        crossAxisSpacing: LayoutConstants.space4,
        mainAxisSpacing: LayoutConstants.space3,
      ),
      itemCount: works.length,
      itemBuilder: (context, index) => WorkGridCard(
        item: works[index],
        onTap: () => onItemTap(works[index]),
      ),
    );
  }

  /// Shows a center menu (Cupertino style) with options.
  static Future<void> showCenterMenu(
    BuildContext context, {
    required List<OptionItem> options,
    Widget? bottomWidget,
    bool useSystemSurface = false,
  }) async {
    final resolvedBackground = useSystemSurface
        ? CupertinoDynamicColor.resolve(
            CupertinoColors.systemBackground,
            context,
          )
        : PrimitivesTokens.colorsDarkGrey;
    final resolvedForeground = useSystemSurface
        ? CupertinoDynamicColor.resolve(CupertinoColors.label, context)
        : AppColor.white;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        return Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: AppTypography.body(
              context,
            ).copyWith(color: resolvedForeground),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenWidth * 0.62,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: resolvedBackground,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final option = options[index];
                            if (option.builder != null) {
                              return option.builder!.call(context, option);
                            }
                            return _CenterMenuItem(
                              option: option,
                              foregroundColor: resolvedForeground,
                            );
                          },
                          separatorBuilder: (context, index) => const SizedBox(
                            height: 24,
                          ),
                        ),
                      ),
                    ),
                    if (bottomWidget != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: resolvedBackground,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: bottomWidget,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Show delete account confirmation
  static void showDeleteAccountConfirmation(
    BuildContext context,
    WalletAddress walletAddress,
    FutureOr<void> Function(WalletAddress address) onRemove,
  ) {
    final theme = Theme.of(context);
    var accountName = walletAddress.name;
    if (accountName.isEmpty) {
      accountName = walletAddress.name.mask(4);
    }

    final bottomSheetKey = GlobalKey();

    unawaited(
      showModalBottomSheet(
        context: context,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        routeSettings: RouteSettings(
          name: ignoreBackLayerPopUpRouteName,
          arguments: {
            'key': bottomSheetKey,
          },
        ),
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => SafeArea(
          key: bottomSheetKey,
          child: ColoredBox(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: theme.auGreyBackground,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete Address',
                    style: AppTypography.h2(context).white,
                  ),
                  const SizedBox(height: 40),
                  RichText(
                    textScaler: MediaQuery.textScalerOf(context),
                    text: TextSpan(
                      style: AppTypography.body(context).white,
                      children: <TextSpan>[
                        const TextSpan(
                          text: 'Are you sure you want to delete the address',
                        ),
                        TextSpan(
                          text: ' "$accountName"',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text: '?',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  PrimaryAsyncButton(
                    text: 'Delete',
                    onTap: () async {
                      await onRemove(walletAddress);
                      if (!context.mounted) {
                        return;
                      }
                      context.pop();
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlineButton(
                    onTap: () => context.pop(),
                    text: 'Cancel',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show delete playlist confirmation.
  static void showDeletePlaylistConfirmation(
    BuildContext context,
    Playlist playlist,
    FutureOr<void> Function(Playlist playlist) onRemove,
  ) {
    final theme = Theme.of(context);
    final playlistTitle = playlist.name.isNotEmpty ? playlist.name : 'Playlist';

    final bottomSheetKey = GlobalKey();

    unawaited(
      showModalBottomSheet(
        context: context,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        routeSettings: RouteSettings(
          name: ignoreBackLayerPopUpRouteName,
          arguments: {
            'key': bottomSheetKey,
          },
        ),
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => SafeArea(
          key: bottomSheetKey,
          child: ColoredBox(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: theme.auGreyBackground,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete playlist',
                    style: AppTypography.h2(context).white,
                  ),
                  const SizedBox(height: 40),
                  RichText(
                    textScaler: MediaQuery.textScalerOf(context),
                    text: TextSpan(
                      style: AppTypography.body(context).white,
                      children: <TextSpan>[
                        const TextSpan(
                          text: 'Are you sure you want to delete the playlist',
                        ),
                        TextSpan(
                          text: ' "$playlistTitle"',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text: '?',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  PrimaryAsyncButton(
                    text: 'Delete',
                    onTap: () async {
                      await onRemove(playlist);
                      if (!context.mounted) {
                        return;
                      }
                      context.pop();
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlineButton(
                    onTap: () => context.pop(),
                    text: 'Cancel',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show info dialog
  static Future<void> showInfoDialog(
    BuildContext context,
    String title,
    String description, {
    bool isDismissible = true,
    int autoDismissAfter = 0,
    String closeButton = '',
    VoidCallback? onClose,
    // FeedbackType? feedback = FeedbackType.selection,
  }) async {
    if (autoDismissAfter > 0) {
      Future.delayed(
        Duration(seconds: autoDismissAfter),
        () => hideInfoDialog(context),
      );
    }

    await showDialog<void>(
      context,
      title,
      SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty) ...[
              Text(
                description,
                style: AppTypography.body(context).white,
              ),
            ],
            const SizedBox(height: 40),
            if (closeButton.isNotEmpty && onClose == null) ...[
              const SizedBox(height: 16),
              OutlineButton(
                onTap: () => Navigator.pop(context),
                text: closeButton,
              ),
              const SizedBox(height: 15),
            ] else if (closeButton.isNotEmpty && onClose != null) ...[
              const SizedBox(height: 16),
              OutlineButton(
                onTap: () {
                  Navigator.pop(context);
                  onClose();
                },
                text: closeButton,
              ),
              const SizedBox(height: 15),
            ],
          ],
        ),
      ),
      isDismissible: isDismissible,
      // feedback: feedback,
    );
  }

  /// Show dialog
  static Future<T?> showDialog<T>(
    BuildContext context,
    String title,
    Widget content, {
    bool isDismissible = true,
    bool isRoundCorner = true,
    Color? backgroundColor,
    int autoDismissAfter = 0,
    // FeedbackType? feedback = FeedbackType.selection,
    EdgeInsets? padding,
    EdgeInsets? paddingTitle,
    bool withCloseIcon = false,
    double spacing = 40,
  }) async {
    currentDialogTitle = title;
    final theme = Theme.of(context);
    final bottomSheetKey = GlobalKey();

    if (autoDismissAfter > 0) {
      Future.delayed(
        Duration(seconds: autoDismissAfter),
        () => hideInfoDialog(context),
      );
    }

    // if (feedback != null) {
    //   Vibrate.feedback(feedback);
    // }

    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      routeSettings: RouteSettings(
        name: ignoreBackLayerPopUpRouteName,
        arguments: {
          'key': bottomSheetKey,
        },
      ),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 150),
        reverseDuration: Duration(milliseconds: 150),
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeOutQuart,
      ),
      builder: (context) => SafeArea(
        child: ColoredBox(
          key: bottomSheetKey,
          color: Colors.transparent,
          child: ClipPath(
            clipper: isRoundCorner ? null : TopRightRectangleClipper(),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor ?? theme.auGreyBackground,
                borderRadius: isRoundCorner
                    ? const BorderRadius.only(
                        topRight: Radius.circular(20),
                      )
                    : null,
              ),
              padding:
                  padding ??
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: paddingTitle ?? const EdgeInsets.all(0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTypography.h2(context).white,
                            ),
                          ),
                          if (withCloseIcon)
                            IconButton(
                              onPressed: () => hideInfoDialog(context),
                              icon: SvgPicture.asset(
                                'assets/images/close.svg',
                                width: 22,
                                height: 22,
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: spacing),
                    content,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hide info dialog
  static void hideInfoDialog(BuildContext context) {
    currentDialogTitle = '';
    try {
      Navigator.popUntil(
        context,
        (route) =>
            route.settings.name != null &&
            !route.settings.name!.toLowerCase().contains('popup'),
      );
    } on Exception catch (_) {}
  }

  /// Show customer support dialog asking whether to attach debug log.
  ///
  /// When user chooses "Attach debug log" or "Send without log", closes the
  /// dialog and calls [supportEmailService].composeSupportEmail with the chosen
  /// [attachLogs] value.
  static Future<void> showCustomerSupport(
    BuildContext context, {
    required SupportEmailService supportEmailService,
  }) async {
    const recipient = 'support@feralfile.com';

    void onConfirmAttachCrashLog({required bool attachLogs}) {
      Navigator.pop(context);
      unawaited(
        supportEmailService.composeSupportEmail(
          recipient: recipient,
          attachLogs: attachLogs,
        ),
      );
    }

    await UIHelper.showDialog<void>(
      context,
      'Attach a debug log?',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended. It helps us fix issues faster by including technical details like app events, device model, and recent errors. It does not include passwords or private keys. After the email opens, you can also attach screenshots or photos.',
            style: AppTypography.body(context).white,
          ),
          SizedBox(height: LayoutConstants.space6),
          PrimaryButton(
            text: 'Attach debug log',
            onTap: () => onConfirmAttachCrashLog(attachLogs: true),
          ),
          SizedBox(height: LayoutConstants.space3),
          OutlineButton(
            text: 'Send without log',
            onTap: () => onConfirmAttachCrashLog(attachLogs: false),
          ),
          SizedBox(height: LayoutConstants.space4),
        ],
      ),
    );
  }

  /// Show center dialog
  static Future<dynamic> showCenterDialog(
    BuildContext context, {
    required Widget content,
    bool isDismissible = true,
  }) async {
    final theme = Theme.of(context);
    return showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            GestureDetector(
              onTap: isDismissible ? () => Navigator.pop(context) : null,
              child: Container(
                color: AppColor.primaryBlack.withValues(alpha: 0.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.auGreyBackground,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  constraints: const BoxConstraints(
                    maxHeight: 600,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 15,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        content,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show drawer action.
  static Future<void> showDrawerAction(
    BuildContext context, {
    required List<OptionItem> options,
    String? title,
  }) async {
    final bottomSheetKey = GlobalKey();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      isScrollControlled: true,
      routeSettings: RouteSettings(
        name: ignoreBackLayerPopUpRouteName,
        arguments: {
          'key': bottomSheetKey,
        },
      ),
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 150),
        reverseDuration: Duration(milliseconds: 150),
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeOutQuart,
      ),
      builder: (context) => ColoredBox(
        key: bottomSheetKey,
        color: AppColor.auGreyBackground,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title ?? '',
                    style: AppTypography.body(context).bold.white,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    constraints: const BoxConstraints(
                      maxWidth: 44,
                      maxHeight: 44,
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColor.white,
                    ),
                  ),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final option = options[index];
                if (option.builder != null) {
                  return option.builder!.call(context, option);
                }
                return DrawerItem(
                  item: option,
                  color: AppColor.white,
                );
              },
              itemCount: options.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                thickness: 1,
                color: AppColor.primaryBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterMenuItem extends StatefulWidget {
  const _CenterMenuItem({
    required this.option,
    required this.foregroundColor,
  });

  final OptionItem option;
  final Color foregroundColor;

  @override
  State<_CenterMenuItem> createState() => _CenterMenuItemState();
}

class _CenterMenuItemState extends State<_CenterMenuItem> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    final foregroundColor = widget.foregroundColor;
    final baseTextStyle =
        option.titleStyle ??
        AppTypography.body(context).copyWith(color: foregroundColor);
    final processingTextStyle =
        option.titleStyleOnPrecessing ??
        baseTextStyle.copyWith(color: AppColor.disabledColor);
    final disabledTextStyle =
        option.titleStyleOnDisable ??
        baseTextStyle.copyWith(color: AppColor.disabledColor);
    final textStyle = !option.isEnable
        ? disabledTextStyle
        : _isProcessing
        ? processingTextStyle
        : baseTextStyle;
    final icon = !option.isEnable
        ? option.iconOnDisable
        : _isProcessing
        ? (option.iconOnProcessing ??
              LoadingIndicator(
                valueColor: AppColor.disabledColor,
                size: LayoutConstants.iconSizeSmall,
              ))
        : option.icon;

    return GestureDetector(
      onTap: () async {
        if (!option.isEnable || _isProcessing) return;
        setState(() => _isProcessing = true);
        await option.onTap?.call();
        if (!mounted) return;
        setState(() => _isProcessing = false);
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          if (icon != null)
            SizedBox(
              width: LayoutConstants.iconSizeMedium,
              height: LayoutConstants.iconSizeMedium,
              child: IconTheme(
                data: IconThemeData(color: foregroundColor),
                child: icon,
              ),
            ),
          if (icon != null) const SizedBox(width: 15),
          Text(option.title ?? '', style: textStyle),
        ],
      ),
    );
  }
}

/// Drawer/settings list row
class DrawerItem extends StatefulWidget {
  const DrawerItem({
    required this.item,
    super.key,
    this.color,
    this.padding = const EdgeInsets.symmetric(
      vertical: 16,
      horizontal: 12,
    ),
  });

  final OptionItem item;
  final Color? color;
  final EdgeInsets padding;

  @override
  State<DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<DrawerItem> {
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = widget.color;
    final defaultTextStyle = AppTypography.body(context).black;
    final customTextStyle = defaultTextStyle.copyWith(color: color);
    final defaultProcessingTextStyle = defaultTextStyle.copyWith(
      color: AppColor.disabledColor,
    );
    final defaultDisabledTextStyle = defaultTextStyle.copyWith(
      color: AppColor.disabledColor,
    );
    final icon = !item.isEnable
        ? (item.iconOnDisable ?? item.icon)
        : isProcessing
        ? (item.iconOnProcessing ??
              LoadingIndicator(
                valueColor: AppColor.disabledColor,
                size: LayoutConstants.iconSizeSmall,
              ))
        : item.icon;
    final titleStyle = !item.isEnable
        ? (item.titleStyleOnDisable ?? defaultDisabledTextStyle)
        : isProcessing
        ? (item.titleStyleOnPrecessing ?? defaultProcessingTextStyle)
        : (item.titleStyle ?? customTextStyle);

    final child = Container(
      color: Colors.transparent,
      width: MediaQuery.of(context).size.width,
      child: Padding(
        padding: widget.padding,
        child: Row(
          children: [
            if (icon != null) ...[
              SizedBox(
                width: LayoutConstants.space7,
                child: Center(child: icon),
              ),
              SizedBox(width: LayoutConstants.space8),
            ],
            Expanded(
              child: Text(
                item.title ?? '',
                style: titleStyle,
              ),
            ),
          ],
        ),
      ),
    );
    return GestureDetector(
      onTap: () async {
        if (!item.isEnable || isProcessing) return;
        setState(() => isProcessing = true);
        await item.onTap?.call();
        if (mounted) setState(() => isProcessing = false);
      },
      child: child,
    );
  }
}

/// Option item for center menu.
class OptionItem {
  OptionItem({
    this.title,
    this.titleStyle,
    this.titleStyleOnPrecessing,
    this.titleStyleOnDisable,
    this.onTap,
    this.isEnable = true,
    this.icon,
    this.iconOnProcessing,
    this.iconOnDisable,
    this.builder,
    this.separator,
  });

  String? title;
  TextStyle? titleStyle;
  TextStyle? titleStyleOnPrecessing;
  TextStyle? titleStyleOnDisable;
  FutureOr<dynamic> Function()? onTap;
  bool isEnable;
  Widget? icon;
  Widget? iconOnProcessing;
  Widget? iconOnDisable;
  Widget Function(BuildContext context, OptionItem item)? builder;
  Widget? separator;

  static OptionItem emptyOptionItem = OptionItem(title: '');
}
