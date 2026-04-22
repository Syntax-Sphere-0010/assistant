import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Brand Colors
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color primaryDark = Color(0xFF4B44CC);

  // Secondary Brand Colors
  static const Color secondary = Color(0xFFFF6584);
  static const Color secondaryLight = Color(0xFFFF8FA3);
  static const Color secondaryDark = Color(0xFFCC4D66);

  // Accent
  static const Color accent = Color(0xFF43E97B);
  static const Color accentLight = Color(0xFF76F0A2);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF8F9FE);
  static const Color backgroundDark = Color(0xFF0F1117);

  // Surfaces
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1A1D27);
  static const Color surfaceDark2 = Color(0xFF242736);

  // Text
  static const Color textPrimary = Color(0xFF1A1D27);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFFADB5BD);
  static const Color textDisabled = Color(0xFFCED4DA);

  // Input
  static const Color inputFill = Color(0xFFF1F3F9);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Status Light (Dark Mode)
  static const Color successLight = Color(0xFF34D399);
  static const Color warningLight = Color(0xFFFBBF24);
  static const Color errorLight = Color(0xFFF87171);
  static const Color infoLight = Color(0xFF60A5FA);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, Color(0xFFFF9A9E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFF8F9FE), Color(0xFFEEF0FC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Overlay
  static const Color overlayLight = Color(0x1A000000);
  static const Color overlayDark = Color(0x80000000);

  // Transparent
  static const Color transparent = Colors.transparent;
}
