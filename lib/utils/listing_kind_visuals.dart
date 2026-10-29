import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../features/stay/setup/stay_option_sets.dart';
import '../features/taxi/taxi_option_sets.dart';

abstract final class ListingKindVisuals {
  static Color accentOf(String listingType) => switch (listingType) {
        'Stay' => StayColors.accent,
        'Taxi' => TaxiColors.accent,
        'Plot' => AppColors.plot,
        _ => AppColors.primary,
      };

  static LinearGradient gradientOf(String listingType) => switch (listingType) {
        'Stay' => StayColors.gradient,
        'Taxi' => TaxiColors.gradient,
        'Plot' => AppColors.plotGradient,
        _ => AppColors.primaryGradient,
      };

  static String labelOf(String listingType) => switch (listingType) {
        'Stay' => 'STAY',
        'Taxi' => 'TAXI',
        'Plot' => 'PLOT',
        _ => 'ROOM',
      };
}
