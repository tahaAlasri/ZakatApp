import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette - Islamic Emerald & Gold
  static const Color emeraldPrimary = Color(0xFF0F5132);
  static const Color emeraldDark = Color(0xFF0A3622);
  static const Color emeraldLight = Color(0xFF198754);
  static const Color emeraldSubtle = Color(0xFFE8F5E9);

  static const Color goldAccent = Color(0xFFD4AF37);
  static const Color goldDark = Color(0xFFB38F26);
  static const Color goldLight = Color(0xFFF1D888);

  // Background & Surfaces - Light Mode
  static const Color lightBg = Color(0xFFF8FAF8);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1E2923);
  static const Color textSecondaryLight = Color(0xFF5A6B62);

  // Background & Surfaces - Dark Mode
  static const Color darkBg = Color(0xFF0E1613);
  static const Color darkSurface = Color(0xFF16221D);
  static const Color darkCard = Color(0xFF1C2B25);
  static const Color textPrimaryDark = Color(0xFFF0F5F2);
  static const Color textSecondaryDark = Color(0xFF9EB2A8);

  // Status & Feedback
  static const Color success = Color(0xFF28A745);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFDC3545);
  static const Color info = Color(0xFF17A2B8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF0F5132),
      Color(0xFF1B4D3E),
    ],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF3E09B),
      Color(0xFFD4AF37),
      Color(0xFFB38F26),
    ],
  );

  static const LinearGradient cardDarkGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [
      Color(0xFF1C2B25),
      Color(0xFF16221D),
    ],
  );
}
