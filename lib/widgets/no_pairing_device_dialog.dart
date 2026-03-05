import 'package:app/design/app_typography.dart';
import 'package:app/design/build/primitives.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/widgets/buttons/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:url_launcher/url_launcher.dart';

/// Dialog for when no pairing device.
class NoPairingDeviceDialog extends StatelessWidget {
  /// Constructor
  const NoPairingDeviceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: LayoutConstants.space6),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: LayoutConstants.space6),
                    Image.asset('assets/images/ff_device.png'),
                    SizedBox(height: LayoutConstants.space5),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Meet FF1',
                          style: AppTypography.body(context).black,
                        ),
                        SizedBox(height: LayoutConstants.space2),
                        Text(
                          'The art computer by Feral File.\nMade to play digital art on any screen.',
                          style: AppTypography.body(context).black,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    SizedBox(height: LayoutConstants.space10),
                    IntrinsicWidth(
                      child: PrimaryButton(
                        elevatedPadding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 11,
                        ),
                        padding: EdgeInsets.zero,
                        text: r'Get your FF1, $1000',
                        textStyle: AppTypography.body(context).black,
                        rightIcon: SvgPicture.asset(
                          'assets/images/arrow_right.svg',
                          width: 12.23,
                          height: 10,
                          colorFilter: const ColorFilter.mode(
                            PrimitivesTokens.colorsBlack,
                            BlendMode.srcIn,
                          ),
                        ),
                        onTap: () async {
                          final uri = Uri.parse(
                            'https://feralfile.com/install',
                          );
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                      ),
                    ),
                    SizedBox(
                      height: LayoutConstants.space10,
                    ),
                    Text(
                      'FF1 is a small computer (128 × 128 × 48 mm)'
                      ' that plays everything: images, video, and'
                      ' real-time interactive software. It connects'
                      ' you to the entire world of digital art, not'
                      ' just Feral File exhibitions.\n\nAdd an'
                      ' Ethereum or Tezos address and FF1 builds a'
                      ' playlist automatically. Designed to pair'
                      ' with FFP, it works with any HDMI screen.',
                      style: AppTypography.h3(context).copyWith(
                        color: PrimitivesTokens.colorsBlack,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
