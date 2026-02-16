import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Light Gray
    primaryColor: const Color(0xFF003366), // Navy Blue Accent
    colorScheme: ColorScheme.light(
      primary: const Color(0xFF003366),
      secondary: const Color(0xFF007BFF),
      surface: Colors.white,
      background: const Color(0xFFF8F9FA),
    ),
    textTheme: GoogleFonts.interTextTheme(),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
  );
}
