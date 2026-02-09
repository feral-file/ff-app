//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//  Copyright © 2024 Bitmark. All rights reserved.
//  Use of this source code is governed by the BSD-2-Clause Plus Patent License
//  that can be found in the LICENSE file.
//

import 'dart:async';

import 'package:app/app/providers/add_address_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

final _log = Logger('AddAddressScreen');

/// Onboarding page for adding a new view-only address.
class AddAddressScreen extends ConsumerStatefulWidget {
  /// Constructor
  const AddAddressScreen({
    super.key,
    this.isFromOnboarding = true,
  });

  /// Whether this page is part of onboarding flow.
  final bool isFromOnboarding;

  @override
  ConsumerState<AddAddressScreen> createState() =>
      _AddAddressInputScreenState();
}

class _AddAddressInputScreenState extends ConsumerState<AddAddressScreen> {
  late final TextEditingController _inputController;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(
      text: kDebugMode ? '0x99fc8AD516FBCC9bA3123D56e63A35d05AA9EFB8' : '',
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _handleVerifyAddress() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    unawaited(
      ref.read(addAddressProvider.notifier).verify(text),
    );
  }

  /// Handle QR scan
  void _handleQRScan() async {
    // TODO: Implement QR scan navigation
    // For now, this is a placeholder
    _log.info('QR scan not yet implemented');
  }

  @override
  Widget build(BuildContext context) {
    final addAddressState = ref.watch(addAddressProvider);

    // Listen for state changes
    ref.listen<AsyncValue<Address?>>(
      addAddressProvider,
      (previous, next) {
        // When address is verified (AsyncData with non-null value), navigate to alias screen
        if (next is AsyncData<Address?> &&
            next.value != null &&
            (previous is! AsyncData<Address?> || previous.value == null)) {
          if (context.mounted) {
            final uri = Uri(
              path: Routes.addAliasPage,
              queryParameters: {
                'address': next.value?.address,
                'domain': next.value?.domain,
              },
            );
            unawaited(context.push(uri.toString()));
          }
        }
      },
    );

    final isSubmitting = addAddressState.isLoading;
    final isInputEmpty = _inputController.text.trim().isEmpty;
    final isSubmitEnabled = !isSubmitting && !isInputEmpty;

    return Scaffold(
      backgroundColor: AppColor.auGreyBackground,
      appBar: const SetupAppBar(
        withDivider: false,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: LayoutConstants.setupPageHorizontal,
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
                          controller: _inputController,
                          enabled: !isSubmitting,
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
                          onChanged: (_) => setState(() {}),
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
                      ]
                    ],
                  ),
                ),
                SizedBox(height: LayoutConstants.space2),
                // Error message
                Align(
                  alignment: Alignment.centerLeft,
                  child: addAddressState.hasError
                      ? Text(
                          "We couldn't validate this address. Check it and try again.",
                          style: AppTypography.body(context).red,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            Positioned(
              bottom: LayoutConstants.space4,
              left: 0,
              right: 0,
              child: PrimaryButton(
                text: 'Submit',
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
