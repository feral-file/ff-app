import 'dart:async';

import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/domain/utils/customer_support_util.dart';
import 'package:app/widgets/buttons/outline_button.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:app/widgets/top_right_rectangle_clipper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// UI helper class
class UIHelper {
  /// Current dialog title
  static String currentDialogTitle = '';

  /// Ignore back layer pop up route name
  static const String ignoreBackLayerPopUpRouteName = 'popUp.ignoreBackLayer';

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
                onTap: onClose,
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
              padding: padding ??
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
                                'assets/images/circle_close.svg',
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

  /// Show customer support
  static Future<void> showCustomerSupport(BuildContext context) async {
    /// On confirm attach crash log
    void onConfirmAttachCrashLog({required bool attachCrashLog}) {
      UIHelper.hideInfoDialog(context);
      unawaited(CustomerSupportUtil.sendSupportEmail(
        attachLogs: attachCrashLog,
      ));
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
            onTap: () => onConfirmAttachCrashLog(attachCrashLog: true),
          ),
          SizedBox(height: LayoutConstants.space3),
          OutlineButton(
            text: 'Send without log',
            onTap: () => onConfirmAttachCrashLog(attachCrashLog: false),
          ),
          SizedBox(height: LayoutConstants.space4),
        ],
      ),
    );
  }
}
