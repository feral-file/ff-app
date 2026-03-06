//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:app/app/providers/add_address_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/app/providers/scan_qr_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/add_alias_screen.dart';
import 'package:app/ui/screens/scan_qr_page.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

final _log = Logger('AddAddressScreen');

/// Page for adding a new view-only address.
class AddAddressScreen extends ConsumerStatefulWidget {
  /// Constructor
  const AddAddressScreen({
    super.key,
  });

  @override
  ConsumerState<AddAddressScreen> createState() =>
      _AddAddressInputScreenState();
}

class _AddAddressInputScreenState extends ConsumerState<AddAddressScreen> {
  late final TextEditingController _inputController;
  final _addressFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(
      text: kDebugMode ? '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8' : '',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _addressFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _addressFocusNode.dispose();
    super.dispose();
  }

  void _handleVerifyAddress() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    unawaited(ref.read(addAddressFlowProvider.notifier).submit(text));
  }

  /// Handle QR scan
  Future<void> _handleQRScan() async {
    final result = await context.push<String>(
      Routes.scanQrPage,
      extra: const ScanQrPagePayload(
        mode: ScanQrMode.address,
      ),
    );
    if (!mounted || result == null || result.isEmpty) {
      return;
    }

    _inputController.text = result;
    _handleVerifyAddress();
    _log.info('Address scanned and submitted');
  }

  @override
  Widget build(BuildContext context) {
    final addAddressFlowState = ref.watch(addAddressFlowProvider);
    final shouldReserveNowDisplayingBar = ref.watch(
      nowDisplayingShouldShowProvider,
    );

    ref.listen<AsyncValue<AddAddressFlowResult>>(
      addAddressFlowProvider,
      (previous, next) {
        if (next case AsyncData(:final value)) {
          if (value case AddAddressFlowNeedsAlias(
            :final address,
            :final domain,
          )) {
            if (context.mounted) {
              final payload = AddAliasScreenPayload(
                address: address,
                domain: domain,
              );
              unawaited(context.push(Routes.addAliasPage, extra: payload));
            }
            return;
          }

          if (value is AddAddressFlowCompleted) {
            if (context.mounted) {
              context.pop();
            }
          }
        }
      },
    );

    final isSubmitting = addAddressFlowState.isLoading;
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
                          focusNode: _addressFocusNode,
                          controller: _inputController,
                          enabled: !isSubmitting,
                          textInputAction: TextInputAction.done,
                          style: AppTypography.body(context).white,
                          cursorColor: isSubmitting
                              ? AppColor.feralFileMediumGrey
                              : AppColor.white,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Address or ENS / Tezos domain',
                            hintStyle: AppTypography.body(context).white,
                          ),
                          onSubmitted: (_) => _handleVerifyAddress(),
                          onChanged: (_) {
                            setState(() {});
                            if (addAddressFlowState.hasError) {
                              ref.read(addAddressFlowProvider.notifier).reset();
                            }
                          },
                        ),
                      ),
                      if (isSubmitting)
                        SizedBox(
                          width: LayoutConstants.iconSizeMedium,
                          height: LayoutConstants.iconSizeMedium,
                          child: CircularProgressIndicator(
                            strokeWidth: LayoutConstants.space1 / 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColor.white,
                            ),
                          ),
                        )
                      else ...[
                        SizedBox(width: LayoutConstants.space3),
                        GestureDetector(
                          onTap: _handleQRScan,
                          child: SvgPicture.asset('assets/images/scan.svg'),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: LayoutConstants.space2),
                // Error message
                Align(
                  alignment: Alignment.centerLeft,
                  child: addAddressFlowState.hasError
                      ? Text(
                          switch (addAddressFlowState.error) {
                            AddAddressException(:final type) => type.message,
                            _ =>
                              "We couldn't validate this address. "
                                  'Check it and try again.',
                          },
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
              child: PrimaryButton(
                text: 'Submit',
                color: PrimitivesTokens.colorsWhite,
                onTap: isSubmitEnabled ? _handleVerifyAddress : null,
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
