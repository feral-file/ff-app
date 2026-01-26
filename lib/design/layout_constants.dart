import 'package:app/design/build/primitives.dart';

/// Layout and spacing constants from design tokens
/// Based on 4px grid system
class LayoutConstants {
  LayoutConstants._();

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
  
  /// Space 8 (32px)
  static final double space8 = PrimitivesTokens.spacingSpace8.toDouble();
  
  /// Space 10 (40px)
  static final double space10 = PrimitivesTokens.spacingSpace10.toDouble();
  
  /// Space 12 (48px)
  static final double space12 = PrimitivesTokens.spacingSpace12.toDouble();
  
  /// Space 16 (64px)
  static final double space16 = PrimitivesTokens.spacingSpace16.toDouble();
  
  /// Space 20 (80px)
  static final double space20 = PrimitivesTokens.spacingSpace20.toDouble();

  // Page padding
  /// Setup page horizontal padding (44px)
  static final double setupPageHorizontal =
      PrimitivesTokens.spacingSetupPageHorizontal.toDouble();
      
  /// Default page horizontal padding (16px)
  static final double pageHorizontalDefault =
      PrimitivesTokens.spacingPageHorizontalDefault.toDouble();

  // Touch targets
  /// Minimum touch target size (44px)
  static final double minTouchTarget =
      PrimitivesTokens.spacingMinTouchTarget.toDouble();
      
  /// Default button height
  static const double buttonHeightDefault = 44;
  
  /// Large button height
  static const double buttonHeightLarge = 52;

  // Icon sizes
  /// Small icon size (12px)
  static final double iconSizeSmall =
      PrimitivesTokens.iconSizesSmall.toDouble();
  
  /// Default icon size (16px)
  static final double iconSizeDefault =
      PrimitivesTokens.iconSizesDefault.toDouble();
      
  /// Medium icon size (20px)
  static final double iconSizeMedium =
      PrimitivesTokens.iconSizesMedium.toDouble();
      
  /// Large icon size (24px)
  static final double iconSizeLarge =
      PrimitivesTokens.iconSizesLarge.toDouble();
}
