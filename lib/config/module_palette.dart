import 'package:flutter/material.dart';
import '../design/tokens/design_colors.dart';

class ModulePalette {
  final Color accent;
  final Color accentDark;
  final Color accentLight;
  final Color surface;
  final LinearGradient gradient;

  const ModulePalette({
    required this.accent,
    required this.accentDark,
    required this.accentLight,
    required this.surface,
    required this.gradient,
  });

  String get hex {
    final rgb = accent.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  static const rooms = ModulePalette(
    accent: DesignColors.primary,
    accentDark: DesignColors.primary,
    accentLight: DesignColors.primaryLight,
    surface: DesignColors.scaffold,
    gradient: DesignGradients.brand,
  );

  static const stays = ModulePalette(
    accent: DesignColors.hotelStart,
    accentDark: DesignColors.hotelEnd,
    accentLight: DesignColors.accentTeal,
    surface: DesignColors.successSoft,
    gradient: DesignGradients.hotel,
  );

  static const jobs = ModulePalette(
    accent: DesignColors.lunchStart,
    accentDark: DesignColors.lunchEnd,
    accentLight: DesignColors.ringLight,
    surface: DesignColors.statusOfferSoft,
    gradient: DesignGradients.lunch,
  );

  static const taxi = ModulePalette(
    accent: DesignColors.breakfastStart,
    accentDark: DesignColors.snackEnd,
    accentLight: DesignColors.breakfastEnd,
    surface: DesignColors.statusAttentionSoft,
    gradient: DesignGradients.breakfast,
  );

  static const trip = ModulePalette(
    accent: DesignColors.primary,
    accentDark: DesignColors.dinnerEnd,
    accentLight: DesignColors.primaryLight,
    surface: DesignColors.primarySoft,
    gradient: DesignGradients.brand,
  );

  static ModulePalette forListingKind(String kind) => switch (kind) {
        'Stay' => stays,
        'Taxi' => taxi,
        'Job' => jobs,
        _ => rooms,
      };
}
