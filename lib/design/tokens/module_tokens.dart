import 'package:flutter/material.dart';
import 'design_colors.dart';

class ModuleTokens {
  final Color accent;
  final Color accentDark;
  final Color accentLight;
  final Color surface;
  final LinearGradient gradient;
  final List<BoxShadow> shadow;

  const ModuleTokens({
    required this.accent,
    required this.accentDark,
    required this.accentLight,
    required this.surface,
    required this.gradient,
    required this.shadow,
  });

  static const ModuleTokens stay = ModuleTokens(
    accent: DesignColors.hotelStart,
    accentDark: DesignColors.hotelEnd,
    accentLight: DesignColors.accentTeal,
    surface: DesignColors.successSoft,
    gradient: DesignGradients.hotel,
    shadow: DesignShadows.hotel,
  );

  static const ModuleTokens jobs = ModuleTokens(
    accent: DesignColors.lunchStart,
    accentDark: DesignColors.lunchEnd,
    accentLight: DesignColors.ringLight,
    surface: DesignColors.statusOfferSoft,
    gradient: DesignGradients.lunch,
    shadow: DesignShadows.lunch,
  );

  static const ModuleTokens taxi = ModuleTokens(
    accent: DesignColors.breakfastStart,
    accentDark: DesignColors.snackEnd,
    accentLight: DesignColors.breakfastEnd,
    surface: DesignColors.statusAttentionSoft,
    gradient: DesignGradients.breakfast,
    shadow: DesignShadows.breakfast,
  );

  static const ModuleTokens trip = ModuleTokens(
    accent: DesignColors.primary,
    accentDark: DesignColors.dinnerEnd,
    accentLight: DesignColors.primaryLight,
    surface: DesignColors.primarySoft,
    gradient: DesignGradients.brand,
    shadow: DesignShadows.brand,
  );

  static const ModuleTokens brand = trip;
}
