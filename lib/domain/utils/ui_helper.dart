import 'dart:async';

import 'package:app/design/app_typography.dart';
import 'package:app/domain/extensions/extensions.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/widgets/buttons/outline_button.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// UI helper class
class UIHelper {
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
}
