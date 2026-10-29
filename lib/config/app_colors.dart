import 'package:flutter/material.dart';

class AppColors {
  // Primary palette (Rooms)
  static const Color primary = Color(0xFF1E3A8A);       // Deep navy
  static const Color primaryLight = Color(0xFF3B82F6);  // Royal blue
  static const Color accent = Color(0xFF0EA5E9);        // Cyan highlight
  static const Color accentLight = Color(0xFF38BDF8);

  // Plot palette — the Plots tab's own theme, distinct from Rooms' blue above.
  static const Color plot = Color(0xFF15803D);      // Forest
  static const Color plotDark = Color(0xFF166534);  // Deep forest
  static const Color plotSurface = Color(0xFFF0FDF4);
  static const Color gold = Color(0xFFB8862E);

  // Stay palette
  static const Color stay = Color(0xFFDB2777);
  static const Color stayDark = Color(0xFFBE185D);
  static const Color stayLight = Color(0xFFF472B6);
  static const Color staySurface = Color(0xFFFDF2F8);

  // Jobs palette
  static const Color job = Color(0xFF7C3AED);
  static const Color jobDark = Color(0xFF6D28D9);
  static const Color jobLight = Color(0xFFA78BFA);
  static const Color jobSurface = Color(0xFFF5F3FF);

  // Taxi palette
  static const Color taxi = Color(0xFF0D9488);
  static const Color taxiDark = Color(0xFF0F766E);
  static const Color taxiLight = Color(0xFF2DD4BF);
  static const Color taxiSurface = Color(0xFFF0FDFA);
  static const Color taxiHeroEnd = Color(0xFF5EEAD4);

  // Hex strings for native MapLibre layer APIs, which require a String not a Color.
  static String hexOf(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  static String get primaryHex => hexOf(primary);
  static String get plotHex => hexOf(plot);
  static String get stayHex => hexOf(stay);
  static String get jobHex => hexOf(job);
  static String get taxiHex => hexOf(taxi);
  static String get userDotHex => hexOf(userDot);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
  );

  static Color accentFor(bool isPlot) => isPlot ? plot : primary;
  static LinearGradient gradientFor(bool isPlot) => isPlot ? plotGradient : primaryGradient;

  static const LinearGradient plotGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF15803D), Color(0xFF166534)],
  );

  static const LinearGradient stayGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [stayLight, stay],
  );

  static const LinearGradient jobGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [jobLight, job],
  );

  static const LinearGradient taxiGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [taxiLight, taxi],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFBBF24), warning],
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
  static const Color scaffoldBg = Color(0xFFFAF8F4);
  static const Color readTick = Color(0xFF34B7F1);

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
  static const Color reportAlert = Color(0xFFEA580C); // burnt-orange — distinct from warning/error
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color warningText = Color(0xFF92400E);
  static const Color successSurface = Color(0xFFDCFCE7);
  static const Color successText = Color(0xFF166534);
  static const Color successDark = Color(0xFF059669);
  static const Color successTrack = Color(0xFFD1FAE5);
  static const Color errorSurface = Color(0xFFFEE2E2);
  static const Color errorText = Color(0xFF991B1B);
  static const Color errorDark = Color(0xFFDC2626);

  // Neutral chips / brand
  static const Color neutralChip = Color(0xFFF1F5F9);
  static const Color neutralChipText = Color(0xFF475569);
  static const Color whatsApp = Color(0xFF25D366);
  static const Color userDot = Color(0xFF1E88E5);
  static const Color furnished = Color(0xFF8B5CF6);

  // Misc
  static const Color divider = Color(0xFFE2E8F0);
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color surfaceWarm = Color(0xFFF3EFE8);
  static const Color shimmerHighlight = surfaceWarm;
  static const Color shadow = Color(0x1A1E3A8A);
}
