import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../config/module_palette.dart';

class TripStatusColors {
  static const Color shortlisted = AppColors.textLight;
  static const Color waiting = AppColors.warning;
  static const Color waitingSurface = AppColors.warningSurface;
  static const Color confirmedByYou = AppColors.tripDark;
  static const Color confirmedByYouSurface = AppColors.tripSurface;
  static const Color both = AppColors.success;
  static const Color bothSurface = AppColors.successSurface;
  static const Color advance = AppColors.tripAdvance;
  static const Color advanceSurface = AppColors.tripAdvanceSurface;
  static const Color failed = AppColors.error;
  static const Color failedSurface = AppColors.errorSurface;
  static const Color booked = AppColors.tripBooked;
  static const Color bookedSurface = AppColors.tripBookedSurface;
}

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
