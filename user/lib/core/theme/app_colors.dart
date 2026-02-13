// VIBRO Color System — White & Navy Enterprise Theme
import 'package:flutter/material.dart';

/// Corporate-grade color palette for VIBRO
/// White-dominant with Navy authority accents
class AppColors {
  AppColors._();

  // Navy Hierarchy
  static const Color deepNavy = Color(0xFF081629);
  static const Color primaryNavy = Color(0xFF0B1F3B);
  static const Color accentNavy = Color(0xFF123A6F);

  // White & Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF4F6F9);
  static const Color divider = Color(0xFFE5E7EB);

  // Text Hierarchy
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);

  // Confidence Badge
  static const Color confidenceHigh = Color(0xFF16A34A);
  static const Color confidenceMedium = Color(0xFFF59E0B);
  static const Color confidenceLow = Color(0xFFDC2626);
  static const Color badgeBackground = Color(0xFFEEF2FF);

  // Semantic Mapping
  static const Color background = white;
  static const Color cardBackground = white;
  static const Color primaryText = textPrimary;
  static const Color secondaryText = textSecondary;
}
