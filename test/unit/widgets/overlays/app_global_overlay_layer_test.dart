import 'package:app/app/providers/now_displaying_provider.dart';
import 'package:app/app/providers/now_displaying_visibility_provider.dart';
import 'package:app/widgets/overlays/app_global_overlay_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _StaticNowDisplayingVisibilityNotifier
    extends NowDisplayingVisibilityNotifier {
  _StaticNowDisplayingVisibilityNotifier(this._state);

  final NowDisplayingVisibilityState _state;

  @override
  NowDisplayingVisibilityState build() => _state;
}

class _StaticNowDisplayingNotifier extends NowDisplayingNotifier {
  _StaticNowDisplayingNotifier(this._state);

  final NowDisplayingStatus _state;

  @override
  NowDisplayingStatus build() => _state;
}

/// Visibility where the now bar is not shown (scroll-hidden / no bar).
const _kHiddenBarVisibility = NowDisplayingVisibilityState(
  shouldShowNowDisplaying: true,
  nowDisplayingVisibility: false,
  bottomSheetVisibility: false,
  keyboardVisibility: false,
  hasFF1: true,
  workDetailPanelExpanded: false,
);

/// Visibility where the now bar is shown.
const _kVisibleBarVisibility = NowDisplayingVisibilityState(
  shouldShowNowDisplaying: true,
  nowDisplayingVisibility: true,
  bottomSheetVisibility: false,
  keyboardVisibility: false,
  hasFF1: true,
  workDetailPanelExpanded: false,
);

Future<void> _pumpLayer(
  WidgetTester tester, {
  required NowDisplayingVisibilityState visibility,
  required double bottomPadding,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: SizedBox.expand()),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nowDisplayingVisibilityProvider.overrideWith(
          () => _StaticNowDisplayingVisibilityNotifier(visibility),
        ),
        nowDisplayingProvider.overrideWith(
          () => _StaticNowDisplayingNotifier(const NoDevicePaired()),
        ),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          padding: EdgeInsets.only(bottom: bottomPadding),
        ),
        child: MaterialApp(
          home: Stack(
            children: [
              AppGlobalOverlayLayer(router: router),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AppGlobalOverlayLayer bottom fade', () {
    testWidgets(
      'paints no bottom fade when now bar is hidden (zero bottom inset)',
      (tester) async {
        await _pumpLayer(
          tester,
          visibility: _kHiddenBarVisibility,
          bottomPadding: 0,
        );

        expect(
          find.byKey(AppGlobalOverlayLayer.bottomFadeGradientKey),
          findsNothing,
        );
      },
    );

    testWidgets(
      'no bottom fade when bar hidden (non-zero bottom inset)',
      (tester) async {
        await _pumpLayer(
          tester,
          visibility: _kHiddenBarVisibility,
          bottomPadding: 34,
        );

        expect(
          find.byKey(AppGlobalOverlayLayer.bottomFadeGradientKey),
          findsNothing,
        );
      },
    );

    testWidgets(
      'bottom fade height matches fade + bottom inset when bar visible',
      (tester) async {
        await _pumpLayer(
          tester,
          visibility: _kVisibleBarVisibility,
          bottomPadding: 34,
        );

        final positioned = tester.widget<Positioned>(
          find.byKey(AppGlobalOverlayLayer.bottomFadeGradientKey),
        );
        expect(positioned.height, 120 + 34);
      },
    );

    testWidgets(
      'bottom fade height is fade-only when bar visible and no inset',
      (tester) async {
        await _pumpLayer(
          tester,
          visibility: _kVisibleBarVisibility,
          bottomPadding: 0,
        );

        final positioned = tester.widget<Positioned>(
          find.byKey(AppGlobalOverlayLayer.bottomFadeGradientKey),
        );
        expect(positioned.height, 120);
      },
    );
  });
}
