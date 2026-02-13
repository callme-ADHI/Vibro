// VIBRO Color System - Luxury Navy Blue Theme
import 'package:flutter/material.dart';

/// Core color palette for VIBRO
/// Following luxury, formal, medical-grade design principles
class AppColors {
  AppColors._();

  // Primary Navy Palette
  static const Color deepNavy = Color(0xFF0A1F44);
  static const Color darkMidnight = Color(0xFF081A38);
  static const Color steelBlue = Color(0xFF2E5BFF);
  static const Color silverGray = Color(0xFFB8C2D1);
  static const Color platinumWhite = Color(0xFFF5F7FA);

  // Alert States
  static const Color success = Color(0xFF00C896);
  static const Color warning = Color(0xFFF5A623);
  static const Color error = Color(0xFFE94B3C);

  // Confidence Badge Colors
  static const Color confidenceHigh = Color(0xFF00C896);
  static const Color confidenceMedium = Color(0xFF2E5BFF);
  static const Color confidenceLow = Color(0xFFF5A623);

  // Semantic Colors
  static const Color background = deepNavy;
  static const Color cardBackground = darkMidnight;
  static const Color primaryText = platinumWhite;
  static const Color secondaryText = silverGray;
  static const Color accentActive = steelBlue;

  // Status Colors
  static const Color statusConnected = Color(0xFF00C896);
  static const Color statusDisconnected = Color(0xFFE94B3C);
  static const Color statusPaused = silverGray;

  // Transparent Overlays
  static Color get overlayLight => Colors.white.withOpacity(0.1);
  static Color get overlayDark => Colors.black.withOpacity(0.3);
  static Color get steelBlueTransparent => steelBlue.withOpacity(0.15);
}
