import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/module_palette.dart';

class TripColors {
  static const Color accent = AppColors.trip;
  static const Color accentDark = AppColors.tripDark;
  static const Color accentLight = AppColors.tripLight;
  static const Color surface = AppColors.tripSurface;
  static const LinearGradient gradient = AppColors.tripGradient;
  static const ModulePalette palette = ModulePalette.trip;
  static const List<Color> dayColors = [
    AppColors.trip,
    AppColors.primary,
    AppColors.stay,
    AppColors.taxi,
    AppColors.job,
    AppColors.plot,
  ];

  static Color dayColor(int day) => dayColors[(day - 1) % dayColors.length];
}
