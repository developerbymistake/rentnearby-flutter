import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../features/stay/setup/stay_option_sets.dart';

abstract final class ListingKindVisuals {
  static Color accentOf(String listingType) => switch (listingType) {
        'Stay' => StayColors.accent,
        'Plot' => AppColors.plot,
        _ => AppColors.primary,
      };

  static LinearGradient gradientOf(String listingType) => switch (listingType) {
        'Stay' => StayColors.gradient,
        'Plot' => AppColors.plotGradient,
        _ => AppColors.primaryGradient,
      };

  static String labelOf(String listingType) => switch (listingType) {
        'Stay' => 'STAY',
        'Plot' => 'PLOT',
        _ => 'ROOM',
      };
}
