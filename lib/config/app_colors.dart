import 'package:flutter/material.dart';

class AppColors {
  // Primary palette
  static const Color primary = Color(0xFF1E3A8A);       // Deep navy
  static const Color primaryLight = Color(0xFF3B82F6);  // Royal blue
  static const Color accent = Color(0xFF0EA5E9);        // Cyan highlight
  static const Color accentLight = Color(0xFF38BDF8);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF0EA5E9)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF3B82F6)],
  );

  // Backgrounds
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFEFF6FF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color scaffoldBg = Color(0xFFF8FAFF);
  static const Color chatBg = Color(0xFFE7ECF3);

  // Text
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMedium = Color(0xFF334155);
  static const Color textLight = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);

  // Misc
  static const Color divider = Color(0xFFE2E8F0);
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFEFF6FF);
  static const Color shadow = Color(0x1A1E3A8A);
}
