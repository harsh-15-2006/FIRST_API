import 'package:flutter/material.dart';

class AppTheme {
  // Core palette
  static const Color primary = Color(0xFF4F46E5); // indigo
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color background = Color(0xFFF7F7FB);

  // Risk colors
  static const Color riskHigh = Color(0xFFDC2626); // red
  static const Color riskMedium = Color(0xFFF59E0B); // amber
  static const Color riskLow = Color(0xFF16A34A); // green
  static const Color riskUnknown = Color(0xFF6B7280); // grey

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        color: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      fontFamily: 'Roboto',
    );
  }

  // ---- Risk-level helpers, shared across analyze + history screens ----

  static Color riskColor(String? level) {
    switch (level) {
      case 'High':
        return riskHigh;
      case 'Medium':
        return riskMedium;
      case 'Low':
        return riskLow;
      default:
        return riskUnknown;
    }
  }

  static IconData riskIcon(String? level) {
    switch (level) {
      case 'High':
        return Icons.warning_rounded;
      case 'Medium':
        return Icons.error_outline_rounded;
      case 'Low':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}