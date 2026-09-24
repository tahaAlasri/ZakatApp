import 'package:flutter/material.dart';

/// Helper utility for responsive typography, scaling, and screen adaptations
class ResponsiveHelper {
  // Base reference width (standard modern smartphone viewport: 390dp)
  static const double _baseWidth = 390.0;
  // Base reference height
  static const double _baseHeight = 844.0;

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

  /// Determine if device is an ultra-compact screen (< 340dp)
  static bool isCompactWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 340;

  /// Determine if device has short vertical height (< 650dp)
  static bool isShortHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 650;

  /// Compute safe responsive font size based on screen width and system text scaling
  /// Clamped between 0.85x and 1.25x of the base font size to prevent overflow.
  static double fontSize(BuildContext context, double baseFontSize) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Calculate scale factor relative to reference width
    final scaleFactor = screenWidth / _baseWidth;

    // Dampen scaling so text doesn't become huge on tablets or tiny on small phones
    final dampenedScale = 1.0 + (scaleFactor - 1.0) * 0.45;
    final clampedScale = dampenedScale.clamp(0.85, 1.25);

    return (baseFontSize * clampedScale).roundToDouble();
  }

  /// Responsive width proportional to screen width
  /// baseValue is the value designed for a 390dp screen
  static double rWidth(BuildContext context, double baseValue) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final scale = (screenWidth / _baseWidth).clamp(0.75, 1.4);
    return (baseValue * scale).roundToDouble();
  }

  /// Responsive height proportional to screen height
  static double rHeight(BuildContext context, double baseValue) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final scale = (screenHeight / _baseHeight).clamp(0.75, 1.3);
    return (baseValue * scale).roundToDouble();
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

  /// Responsive symmetric padding
  static EdgeInsets rPadding(BuildContext context, {double horizontal = 16, double vertical = 16}) {
    final w = width(context);
    final scale = (w / _baseWidth).clamp(0.75, 1.3);
    return EdgeInsets.symmetric(
      horizontal: (horizontal * scale).roundToDouble(),
      vertical: (vertical * scale).roundToDouble(),
    );
  }

  /// Responsive spacing (SizedBox height/width)
  static double rSpacing(BuildContext context, double baseSpacing) {
    final w = width(context);
    final scale = (w / _baseWidth).clamp(0.8, 1.3);
    return (baseSpacing * scale).roundToDouble();
  }

  /// Responsive icon size
  static double rIconSize(BuildContext context, double baseSize) {
    final w = width(context);
    final scale = (w / _baseWidth).clamp(0.8, 1.25);
    return (baseSize * scale).roundToDouble();
  }
  /// Responsive grid columns based on screen width
  static int responsiveColumns(BuildContext context, {int phone = 2, int tablet = 3, int desktop = 4}) {
    final w = width(context);
    if (w >= 900) return desktop;
    if (w >= 600) return tablet;
    return phone;
  }

  /// Responsive grid aspect ratio
  static double responsiveGridAspectRatio(BuildContext context, {double phone = 1.0, double tablet = 1.25}) {
    if (isTablet(context)) return tablet;
    if (isSmallScreen(context)) return phone * 0.92;
    return phone;
  }
}

/// Extension on BuildContext for quick access to responsive dimensions & fonts
extension ResponsiveContext on BuildContext {
  double get screenWidth => ResponsiveHelper.width(this);
  double get screenHeight => ResponsiveHelper.height(this);
  bool get isTablet => ResponsiveHelper.isTablet(this);
  bool get isSmallScreen => ResponsiveHelper.isSmallScreen(this);
  bool get isCompactWidth => ResponsiveHelper.isCompactWidth(this);
  bool get isShortHeight => ResponsiveHelper.isShortHeight(this);
  double rFont(double baseSize) => ResponsiveHelper.fontSize(this, baseSize);
  double rWidth(double baseValue) => ResponsiveHelper.rWidth(this, baseValue);
  double rHeight(double baseValue) => ResponsiveHelper.rHeight(this, baseValue);
  EdgeInsets rPadding({double horizontal = 16, double vertical = 16}) =>
      ResponsiveHelper.rPadding(this, horizontal: horizontal, vertical: vertical);
  double rSpacing(double baseSpacing) => ResponsiveHelper.rSpacing(this, baseSpacing);
  double rIconSize(double baseSize) => ResponsiveHelper.rIconSize(this, baseSize);
  int rColumns({int phone = 2, int tablet = 3, int desktop = 4}) =>
      ResponsiveHelper.responsiveColumns(this, phone: phone, tablet: tablet, desktop: desktop);
  double rGridAspectRatio({double phone = 1.0, double tablet = 1.25}) =>
      ResponsiveHelper.responsiveGridAspectRatio(this, phone: phone, tablet: tablet);
}

/// A responsive container that centers content and constrains its maximum width on tablets and desktop
class ResponsiveConstraint extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveConstraint({
    super.key,
    required this.child,
    this.maxWidth = 680,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = padding != null ? Padding(padding: padding!, child: child) : child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: content,
      ),
    );
  }
}

