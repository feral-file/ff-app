import 'package:app/design/build/primitives.dart';

/// Layout and spacing constants from design tokens
/// Based on 4px grid system
class LayoutConstants {
  LayoutConstants._();

  // Borders / dividers
  /// Default divider thickness.
  ///
  /// Keep thickness values centralized to avoid hard-coded sizing in widgets.
  static const double dividerThickness = 1;

  // Carousel sizes (from DP1CarouselTokens)
  /// Height for DP-1 carousel rows (65.0 from DP1CarouselTokens.itemHeight).
  ///
  /// This is a UI layout constant used by list rows to reserve space.
  static const double dp1CarouselHeight = 65;

  /// Content padding horizontal for DP-1 carousel (12.0 from DP1CarouselTokens).
  static const double dp1CarouselContentPaddingHorizontal = 12;

  /// Content padding vertical for DP-1 carousel (0.0 from DP1CarouselTokens).
  static const double dp1CarouselContentPaddingVertical = 0;

  // Work item thumbnail sizes (from ArtworkItemTokens)
  /// Container width for work thumbnails in carousel (51.83 from ArtworkItemTokens.containerWidth).
  static const double workThumbnailContainerWidth = 51.83;

  /// Container height for work thumbnails in carousel (65.0 from ArtworkItemTokens.containerHeight).
  static const double workThumbnailContainerHeight = 65;

  /// Container padding for work thumbnails (2.76 from ArtworkItemTokens.containerPadding).
  static const double workThumbnailContainerPadding = 2.76;

  /// Gap between work thumbnails in carousel (2.76 from ArtworkItemTokens.containerGap).
  static const double workThumbnailGap = 2.76;

  /// Image width inside work thumbnail (45.9 from ArtworkItemTokens.imageWidth).
  static const double workThumbnailImageWidth = 45.9;

  /// Image height inside work thumbnail (59.49 from ArtworkItemTokens.imageHeight).
  static const double workThumbnailImageHeight = 59.49;

  // Grid ratios
  /// Works grid child aspect ratio (width / height).
  ///
  /// Centralized to avoid hard-coded sizing in UI widgets.
  static const double worksGridChildAspectRatio = 188 / 307;

  /// Default label column width for key/value detail rows.
  static const double detailLabelWidth = 120;

  // Spacing scale (4px base unit)
  /// Space 1 (4px)
  static final double space1 = PrimitivesTokens.spacingSpace1.toDouble();

  /// Space 2 (8px)
  static final double space2 = PrimitivesTokens.spacingSpace2.toDouble();

  /// Space 3 (12px)
  static final double space3 = PrimitivesTokens.spacingSpace3.toDouble();

  /// Space 4 (16px)
  static final double space4 = PrimitivesTokens.spacingSpace4.toDouble();

  /// Space 5 (20px)
  static final double space5 = PrimitivesTokens.spacingSpace5.toDouble();

  /// Space 6 (24px)
  static final double space6 = PrimitivesTokens.spacingSpace6.toDouble();

  /// Space 7 (28px)
  static final double space7 = PrimitivesTokens.spacingSpace7.toDouble();

  /// Space 8 (32px)
  static final double space8 = PrimitivesTokens.spacingSpace8.toDouble();

  /// Space 10 (40px)
  static final double space10 = PrimitivesTokens.spacingSpace10.toDouble();

  /// Space 12 (48px)
  static final double space12 = PrimitivesTokens.spacingSpace12.toDouble();

  /// Space 16 (64px)
  static final double space16 = PrimitivesTokens.spacingSpace16.toDouble();

  /// Space 18 (72px)
  static final double space18 = PrimitivesTokens.spacingSpace18.toDouble();

  /// Space 20 (80px)
  static final double space20 = PrimitivesTokens.spacingSpace20.toDouble();

  // Page padding
  /// Horizontal padding for hero/onboarding/setup-wizard screens that show
  /// large title text with minimal interactive content (44px).
  static final double setupPageHorizontal = PrimitivesTokens
      .spacingSetupPageHorizontal
      .toDouble();

  /// Horizontal padding for content, list, and form screens (16px).
  static final double pageHorizontalDefault = PrimitivesTokens
      .spacingPageHorizontalDefault
      .toDouble();

  // Touch targets
  /// Minimum touch target size (44px)
  static final double minTouchTarget = PrimitivesTokens.spacingMinTouchTarget
      .toDouble();

  /// Default button height
  static const double buttonHeightDefault = 44;

  /// Large button height
  static const double buttonHeightLarge = 52;

  // Icon sizes
  /// Small icon size (12px)
  static final double iconSizeSmall = PrimitivesTokens.iconSizesSmall
      .toDouble();

  /// Default icon size (16px)
  static final double iconSizeDefault = PrimitivesTokens.iconSizesDefault
      .toDouble();

  /// Medium icon size (20px)
  static final double iconSizeMedium = PrimitivesTokens.iconSizesMedium
      .toDouble();

  /// Large icon size (24px)
  static final double iconSizeLarge = PrimitivesTokens.iconSizesLarge
      .toDouble();

  // Now Displaying bar (approximate sizing)
  //
  // Per repo rules: avoid hard-coded numeric sizing in widgets.
  // Per app preference: do not add new `const` sizing to LayoutConstants.
  //
  // These getters use the nearest available spacing values.

  /// Collapsed bar height (nearest to legacy 57px).
  static double get nowDisplayingBarCollapsedHeight => space12 + space2;

  /// Expanded bar height (nearest to legacy 316px).
  static double get nowDisplayingBarExpandedHeight =>
      space20 + space20 + space20 + space20;

  /// Card corner radius (nearest to legacy 5px).
  static double get nowDisplayingBarCornerRadius => space1;

  /// Card padding top (nearest to legacy 5px).
  static double get nowDisplayingBarPaddingTop => space1;

  /// Card padding horizontal (nearest to legacy 10px).
  static double get nowDisplayingBarPaddingHorizontal => space3;

  /// Card padding bottom (legacy token already matches spacing scale: 8px).
  static double get nowDisplayingBarPaddingBottom => space2;

  /// Top line width.
  static double get nowDisplayingBarTopLineWidth => space8;

  /// Top line height.
  static double get nowDisplayingBarTopLineHeight =>
      dividerThickness + dividerThickness;

  /// Bottom offset used by the global overlay.
  static double get nowDisplayingBarOverlayBottomOffset => space2;

  /// Reserved height to keep scrollable content above the overlay.
  static double get nowDisplayingBarReservedHeight =>
      nowDisplayingBarCollapsedHeight + nowDisplayingBarOverlayBottomOffset;

  // Now Displaying display item (from DisplayItemTokens)
  /// Thumbnail width (65.78 from DisplayItemTokens.thumbWidth).
  static const double nowDisplayingDisplayItemThumbWidth = 65.78;

  /// Thumbnail height (37 from DisplayItemTokens.thumbHeight).
  static const double nowDisplayingDisplayItemThumbHeight = 37;

  /// Gap between thumbnail and text (12 from DisplayItemTokens.gap).
  static double get nowDisplayingDisplayItemGap => space3;

  /// Vertical offset between artist and title text (-3 from DisplayItemTokens.textArtworkGap).
  static const double nowDisplayingDisplayItemTextArtworkGap = -3;

  /// Gap between list items in expanded bar (20 from NowPlayingBarTokens.bottomDisplayItemListGap).
  static double get nowDisplayingExpandedItemGap => space5;

  /// Vertical gap between sections in expanded bar (20 from NowPlayingBarTokens.bottomVerticalGap).
  static double get nowDisplayingExpandedVerticalGap => space5;

  // Now Playing Bar tokens (from NowPlayingBarTokens)
  static double get nowPlayingBarBottomDeviceNavGap => space3;
  static double get nowPlayingBarBottomDisplayItemListGap => space5;
  static double get nowPlayingBarBottomVerticalGap => space5;
  static double get nowPlayingBarCollapseHeight => space12 + space2;
  static double get nowPlayingBarCornerRadius => space1;
  static double get nowPlayingBarExpandedHeight => space20 * 4;
  static double get nowPlayingBarPaddingBottom => space2;
  static double get nowPlayingBarPaddingHorizontal => space3;
  static double get nowPlayingBarPaddingTop => space1;
  static double get nowPlayingBarTopLineCornerRadius => space2;
  static double get nowPlayingBarTopLineHeight => dividerThickness * 2;
  static double get nowPlayingBarTopLineStrokeWeight => dividerThickness * 2;
  static double get nowPlayingBarTopLineWidth => space8;

  /// Approximate height of the header above the list in the expanded bar
  /// (TopLine + gaps + DeviceSubNav). Used to estimate visible list indices from scroll offset.
  static const double nowDisplayingExpandedListHeaderHeight = 80;

  /// Approximate height per row in the expanded bar list (thumbnail row + gap).
  static const double nowDisplayingExpandedListItemHeight = 64;

  /// Extra items to include when expanding the window on scroll (above and below visible).
  static const int nowDisplayingScrollMarginItems = 10;

  // Sleep Mode Indicator tokens (from SleepModeIndicatorTokens)
  static double get sleepModeIndicatorSize => space6 + space1;
  static double get sleepModeIndicatorPadding => space3;
}
