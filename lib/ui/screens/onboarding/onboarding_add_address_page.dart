import 'dart:async';

import 'package:app/app/providers/addresses_provider.dart';
import 'package:app/app/providers/indexer_tokens_provider.dart';
import 'package:app/app/providers/services_provider.dart';
import 'package:app/app/routing/routes.dart';
import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/domain/models/models.dart';
import 'package:app/ui/screens/ff1_setup/connect_ff1_page.dart';
import 'package:app/ui/ui_helper.dart';
import 'package:app/widgets/appbars/setup_app_bar.dart';
import 'package:app/widgets/loading_view.dart';
import 'package:app/widgets/onboarding/onboarding_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

/// Payload for the onboarding add address page
class OnboardingAddAddressPagePayload {
  /// Constructor
  OnboardingAddAddressPagePayload({
    this.deeplink,
  });

  /// Optional deeplink carried through the onboarding flow.
  final String? deeplink;
}

/// Onboarding add address page.
class OnboardingAddAddressPage extends ConsumerWidget {
  /// Creates an OnboardingAddAddressPage.
  const OnboardingAddAddressPage({
    required this.payload,
    super.key,
  });

  /// Payload for the page
  final OnboardingAddAddressPagePayload payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: PrimitivesTokens.colorsDarkGrey,
      appBar: const SetupAppBar(
        withDivider: false,
      ),
      body: OnboardingShell(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'See the art you already own',
              style: AppTypography.h2(context).white,
            ),
            SizedBox(height: ContentRhythm.titleSupportGap),
            Text(
              'Add your Ethereum and Tezos addresses to pull in the works '
              'you collect. Use the app as a clear lens on your digital '
              'collection, '
              'even before you connect a device.',
              style: ContentRhythm.title(context),
            ),
            SizedBox(height: ContentRhythm.titleSupportGap),
            const _AddressList(),
          ],
        ),
        primaryButton: Row(
          children: [
            SvgPicture.asset(
              'assets/images/add_blue.svg',
              colorFilter: const ColorFilter.mode(
                PrimitivesTokens.colorsBlack,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: LayoutConstants.space2),
            Text(
              'Add Address',
              style: AppTypography.body(context).black,
            ),
          ],
        ),
        onPrimaryPressed: () => _onAddAddressPressed(context),
        secondaryButton: Consumer(
          builder: (context, ref, _) {
            final addressesAsync = ref.watch(addressesProvider);
            final addresses = addressesAsync.value ?? [];

            return Row(
              children: [
                Text(
                  addresses.isEmpty ? 'Skip for now' : 'Next',
                  style: AppTypography.body(context).lightBlue,
                ),
                SizedBox(width: LayoutConstants.space2),
                SvgPicture.asset(
                  'assets/images/arrow_right.svg',
                  colorFilter: const ColorFilter.mode(
                    PrimitivesTokens.colorsLightBlue,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            );
          },
        ),
        onSecondaryPressed: () async => _onNext(context, ref),
        hintText: 'You can always add addresses later.',
      ),
    );
  }

  void _onAddAddressPressed(BuildContext context) {
    unawaited(context.push(Routes.addAddressPage));
  }

  Future<void> _onNext(BuildContext context, WidgetRef ref) async {
    unawaited(
      ref
          .read(tokensSyncCoordinatorProvider.notifier)
          .syncAllTrackedAddresses(),
    );

    if (payload.deeplink != null && payload.deeplink!.isNotEmpty) {
      await context.push(
        Routes.connectFF1Page,
        extra: ConnectFF1PagePayload(
          deeplink: payload.deeplink,
        ),
      );
    } else {
      unawaited(context.push(Routes.onboardingSetupFf1Page));
    }
  }
}

class _AddressList extends ConsumerWidget {
  const _AddressList();

  void _onDelete(
    BuildContext context,
    WidgetRef ref,
    WalletAddress walletAddress,
  ) {
    UIHelper.showDeleteAccountConfirmation(context, walletAddress, (
      address,
    ) async {
      final addressService = ref.read(addressServiceProvider);
      await addressService.removeAddress(
        walletAddress: address,
      );
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressesProvider);

    return addressesAsync.when(
      data: (addresses) {
        if (addresses.isEmpty) {
          return const SizedBox.shrink();
        }

        return ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: addresses.length,
          itemBuilder: (context, index) {
            return Column(
              children: [
                _AddressRow(
                  address: addresses[index],
                  onDelete: (walletAddress) =>
                      _onDelete(context, ref, walletAddress),
                ),
              ],
            );
          },
        );
      },
      loading: () => const Center(
        child: LoadingWidget(showText: false),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.onDelete});

  final WalletAddress address;
  final void Function(WalletAddress) onDelete;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.zero,
      decoration: const BoxDecoration(
        // top border only
        border: Border(
          top: BorderSide(),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: LayoutConstants.space3 - 1,
                bottom: LayoutConstants.space3,
              ),
              child: Text(
                address.name,
                style: ContentRhythm.supporting(context),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onDelete(address),
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.transparent,
              constraints: BoxConstraints(
                minHeight: LayoutConstants.minTouchTarget,
                minWidth: LayoutConstants.minTouchTarget,
              ),
              padding: EdgeInsets.only(
                top: LayoutConstants.space3 - 1,
                bottom: LayoutConstants.space3,
                left: LayoutConstants.space3,
              ),
              child: SvgPicture.asset('assets/images/minus.svg'),
            ),
          ),
        ],
      ),
    );
  }
}
