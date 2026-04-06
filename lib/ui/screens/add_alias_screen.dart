//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/app/providers/add_address_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/buttons/outline_button.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// Payload for the add alias screen
class AddAliasScreenPayload {
  /// Constructor
  const AddAliasScreenPayload({
    required this.address,
    this.domain,
  });

  /// The verified address to add alias for
  final String address;

  /// The domain of verified address
  final String? domain;
}

/// Screen for adding alias to a verified address.
class AddAliasScreen extends ConsumerStatefulWidget {
  /// Constructor
  const AddAliasScreen({
    required this.payload,
    super.key,
  });

  /// Payload for the screen
  final AddAliasScreenPayload payload;

  @override
  ConsumerState<AddAliasScreen> createState() => _AddAliasScreenState();
}

class _AddAliasScreenState extends ConsumerState<AddAliasScreen> {
  late final TextEditingController _inputController;
  final _aliasFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    // Auto focus on input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _aliasFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _aliasFocusNode.dispose();
    super.dispose();
  }

  void _handleAddAddress({required bool skipAlias}) {
    final alias = skipAlias
        ? widget.payload.domain
        : _inputController.text.trim();
    unawaited(
      ref
          .read(
            addAliasProvider.notifier,
          )
          .add(widget.payload.address, alias),
    );
  }

  @override
  Widget build(BuildContext context) {
    final addState = ref.watch(addAliasProvider);
    final shouldReserveNowDisplayingBar = ref.watch(
      nowDisplayingShouldShowProvider,
    );

    // Listen for success and pop
    ref.listen<AsyncValue<void>>(
      addAliasProvider,
      (previous, next) {
        // When address is successfully added, pop
        if (next is AsyncData<void>) {
          if (context.mounted) {
            context
              ..pop()
              ..pop();
          }
        }
      },
    );

    final isSubmitting = addState.isLoading;
    final isInputEmpty = _inputController.text.trim().isEmpty;
    final isSubmitEnabled = !isSubmitting && !isInputEmpty;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final reservedBottomBarHeight = shouldReserveNowDisplayingBar
        ? LayoutConstants.nowDisplayingBarReservedHeight
        : 0.0;
    final bottomInset = bottomPadding + reservedBottomBarHeight;

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: const SetupAppBar(
        withDivider: false,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: LayoutConstants.pageHorizontalDefault,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: LayoutConstants.space16 * 3.4),
                // Input field
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: LayoutConstants.space5,
                    vertical:
                        LayoutConstants.space5 + LayoutConstants.space1 / 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColor.primaryBlack,
                    borderRadius: BorderRadius.circular(
                      LayoutConstants.space1 + LayoutConstants.space1 / 4,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: GoldPathPatrolKeys.onboardingAddAliasInput,
                          controller: _inputController,
                          focusNode: _aliasFocusNode,
                          enabled: !isSubmitting,
                          style: AppTypography.body(context).white,
                          cursorColor: isSubmitting
                              ? AppColor.feralFileMediumGrey
                              : AppColor.white,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Alias (optional)',
                            hintStyle: AppTypography.body(context).white,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: LayoutConstants.space2),
                // Error message
                Align(
                  alignment: Alignment.centerLeft,
                  child: addState.hasError
                      ? Text(
                          "We couldn't add this address. Please try again.",
                          style: AppTypography.body(context).red,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            Positioned(
              bottom: LayoutConstants.space4 + bottomInset,
              left: 0,
              right: 0,
              child: isInputEmpty
                  ? SizedBox(
                      width: double.infinity,
                      child: OutlineButton(
                        key: GoldPathPatrolKeys.onboardingAddAliasSkip,
                        text: 'Skip',
                        textColor: PrimitivesTokens.colorsWhite,
                        borderColor: PrimitivesTokens.colorsWhite,
                        rightIcon: SvgPicture.asset(
                          'assets/images/arrow_right.svg',
                          colorFilter: const ColorFilter.mode(
                            PrimitivesTokens.colorsWhite,
                            BlendMode.srcIn,
                          ),
                        ),
                        onTap: isSubmitting
                            ? null
                            : () => _handleAddAddress(skipAlias: true),
                      ),
                    )
                  : PrimaryButton(
                      key: GoldPathPatrolKeys.onboardingAddAliasSubmit,
                      text: 'Submit',
                      color: PrimitivesTokens.colorsWhite,
                      onTap: isSubmitEnabled
                          ? () => _handleAddAddress(skipAlias: false)
                          : null,
                      isProcessing: isSubmitting,
                      enabled: isSubmitEnabled,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
