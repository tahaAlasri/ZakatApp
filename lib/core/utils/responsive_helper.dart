import 'package:flutter/material.dart';

/// Helper utility for responsive typography, scaling, and screen adaptations
class ResponsiveHelper {
  // Base reference width (standard modern smartphone viewport: 390dp)
  static const double _baseWidth = 390.0;

  /// Get current screen width
  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  /// Get current screen height
  static double height(BuildContext context) => MediaQuery.sizeOf(context).height;

  /// Determine if device is a tablet or large screen
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  /// Determine if device is a compact/small screen (< 360dp)
  static bool isSmallScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 360;

  /// Compute safe responsive font size based on screen width and system text scaling
  /// Clamped between 0.85x and 1.25x of the base font size to prevent overflow.
  static double fontSize(BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Calculate scale factor relative to reference width
    final scaleFactor = screenWidth / _baseWidth;

    // Dampen scaling so text doesn't become huge on tablets or tiny on small phones
    final dampenedScale = 1.0 + (scaleFactor - 1.0) * 0.45;
    final clampedScale = dampenedScale.clamp(0.88, 1.25);

    return (baseFontSize * clampedScale).roundToDouble();
  }

  /// Responsive padding based on device width
  static EdgeInsets screenPadding(BuildContext context) {
    final w = width(context);
    if (w >= 600) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    } else if (w < 360) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }
}

/// Extension on BuildContext for quick access to responsive dimensions & fonts
extension ResponsiveContext on BuildContext {
  double get screenWidth => ResponsiveHelper.width(this);
  double get screenHeight => ResponsiveHelper.height(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isSmallScreen => ResponsiveHelper.isSmallScreen(this);
  double rFont(double baseSize) => ResponsiveHelper.fontSize(this, baseSize);
}
