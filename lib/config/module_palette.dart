import 'package:flutter/material.dart';
import 'app_colors.dart';

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

  String get hex => AppColors.hexOf(accent);

  static const rooms = ModulePalette(
    accent: AppColors.primary,
    accentDark: AppColors.primary,
    accentLight: AppColors.primaryLight,
    surface: AppColors.surface,
    gradient: AppColors.primaryGradient,
  );

  static const plots = ModulePalette(
    accent: AppColors.plot,
    accentDark: AppColors.plotDark,
    accentLight: AppColors.plot,
    surface: AppColors.plotSurface,
    gradient: AppColors.plotGradient,
  );

  static const stays = ModulePalette(
    accent: AppColors.stay,
    accentDark: AppColors.stayDark,
    accentLight: AppColors.stayLight,
    surface: AppColors.staySurface,
    gradient: AppColors.stayGradient,
  );

  static const jobs = ModulePalette(
    accent: AppColors.job,
    accentDark: AppColors.jobDark,
    accentLight: AppColors.jobLight,
    surface: AppColors.jobSurface,
    gradient: AppColors.jobGradient,
  );

  static const taxi = ModulePalette(
    accent: AppColors.taxi,
    accentDark: AppColors.taxiDark,
    accentLight: AppColors.taxiLight,
    surface: AppColors.taxiSurface,
    gradient: AppColors.taxiGradient,
  );

  static ModulePalette forListingKind(String kind) => switch (kind) {
        'Stay' => stays,
        'Taxi' => taxi,
        'Plot' => plots,
        'Job' => jobs,
        _ => rooms,
      };
}
