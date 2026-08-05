import 'package:flutter/material.dart';

class AppColors {
  // Primary palette (Rooms)
  static const Color primary = Color(0xFF1E3A8A);       // Deep navy
  static const Color primaryLight = Color(0xFF3B82F6);  // Royal blue
  static const Color accent = Color(0xFF0EA5E9);        // Cyan highlight
  static const Color accentLight = Color(0xFF38BDF8);

  // Plot palette — the Plots tab's own theme, distinct from Rooms' blue above.
  static const Color plot = Color(0xFF92400E);      // Brown
  static const Color plotDark = Color(0xFF78350F);  // Dark brown

  // Services palette — the Services tab's own scaffold + feature-highlights
  // tint, distinct from Rooms' blue and Plots' brown above.
  static const Color servicesFeatureLight = Color(0xFFE3F0DE);
  static const Color servicesFeatureDark = Color(0xFFBFE0B2);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
  );

  static const LinearGradient plotGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF92400E), Color(0xFF78350F)],
  );

  static const LinearGradient servicesFeatureGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE3F0DE), Color(0xFFBFE0B2)],
  );

  // Services Share Card — a fixed "Ocean Breeze" brand gradient (deliberately NOT the rotating
  // ServiceZone.accent tint) so a shared/printed card looks the same regardless of the service's
  // category rail position.
  static const Color oceanBreeze = accent; // Color(0xFF0EA5E9) — same value as the cyan highlight above
  static const LinearGradient oceanBreezeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [oceanBreeze, Color(0xFF0284C7)],
  );

  // Service Detail "See Your Journey" CTA. Deliberately no begin/end params (matches the exact
  // angle already approved in the mockup, which also omits them).
  static const LinearGradient amberGlowGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFEA580C)],
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
  static const Color servicesScaffoldBg = Color(0xFFF7F1E8);
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
  static const Color reportAlert = Color(0xFFEA580C); // burnt-orange — distinct from warning/error

  // Misc
  static const Color divider = Color(0xFFE2E8F0);
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFEFF6FF);
  static const Color shadow = Color(0x1A1E3A8A);
}
