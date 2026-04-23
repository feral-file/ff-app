import 'package:app/design/app_typography.dart';
import 'package:app/design/content_rhythm.dart';
import 'package:app/design/layout_constants.dart';
import 'package:app/theme/app_color.dart';
import 'package:app/ui/screens/all_channels/publisher_section_header_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PublisherSectionHeaderDelegate', () {
    test('maxExtent returns correct height including top padding', () {
      final delegate = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: LayoutConstants.space4,
      );

      // maxExtent = base header height (40) + top padding (16)
      expect(delegate.maxExtent, 40 + LayoutConstants.space4);
    });

    test('minExtent equals maxExtent for non-shrinking header', () {
      final delegate = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: LayoutConstants.space4,
      );

      // Sticky headers do not shrink
      expect(delegate.minExtent, delegate.maxExtent);
    });

    test('maxExtent adjusts with different top padding values', () {
      const baseHeight = 40.0;

      final delegateWithZeroPadding = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: 0,
      );
      expect(delegateWithZeroPadding.maxExtent, baseHeight);

      final delegateWithSpace4 = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: LayoutConstants.space4,
      );
      expect(
        delegateWithSpace4.maxExtent,
        baseHeight + LayoutConstants.space4,
      );
    });

    test('shouldRebuild returns true when title changes', () {
      final oldDelegate = PublisherSectionHeaderDelegate(
        title: 'Old Publisher',
        topPadding: LayoutConstants.space4,
      );
      final newDelegate = PublisherSectionHeaderDelegate(
        title: 'New Publisher',
        topPadding: LayoutConstants.space4,
      );

      expect(newDelegate.shouldRebuild(oldDelegate), isTrue);
    });

    test('shouldRebuild returns true when topPadding changes', () {
      final oldDelegate = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: 0,
      );
      final newDelegate = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: LayoutConstants.space4,
      );

      expect(newDelegate.shouldRebuild(oldDelegate), isTrue);
    });

    test('shouldRebuild returns false when nothing changes', () {
      final oldDelegate = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: LayoutConstants.space4,
      );
      final newDelegate = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: LayoutConstants.space4,
      );

      expect(newDelegate.shouldRebuild(oldDelegate), isFalse);
    });

    testWidgets('build renders title with correct styling', (tester) async {
      final delegate = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: LayoutConstants.space4,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: delegate,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify title text is rendered
      expect(find.text('Test Publisher'), findsOneWidget);

      // Verify text style is h3 white
      final textWidget = tester.widget<Text>(find.text('Test Publisher'));
      final context = tester.element(find.text('Test Publisher'));
      final expectedStyle = AppTypography.h3(context).white;
      expect(textWidget.style?.fontSize, expectedStyle.fontSize);
      expect(textWidget.style?.color, expectedStyle.color);
    });

    testWidgets('build renders with correct background color', (tester) async {
      final delegate = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: delegate,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify background color
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(SliverPersistentHeader),
          matching: find.byType(Container),
        ),
      );
      expect(container.color, AppColor.auGreyBackground);
    });

    testWidgets('build applies correct padding', (tester) async {
      final delegate = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: LayoutConstants.space4,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: delegate,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify padding
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(SliverPersistentHeader),
          matching: find.byType(Container),
        ),
      );
      final padding = container.padding as EdgeInsets;
      expect(padding.left, ContentRhythm.horizontalRail);
      expect(padding.right, ContentRhythm.horizontalRail);
      expect(padding.bottom, LayoutConstants.space3);
      expect(padding.top, LayoutConstants.space4);
    });

    testWidgets('build aligns text to bottom left', (tester) async {
      final delegate = PublisherSectionHeaderDelegate(
        title: 'Test Publisher',
        topPadding: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: delegate,
                ),
              ],
            ),
          ),
        ),
      );

      // Verify alignment
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(SliverPersistentHeader),
          matching: find.byType(Container),
        ),
      );
      expect(container.alignment, Alignment.bottomLeft);
    });
  });
}
