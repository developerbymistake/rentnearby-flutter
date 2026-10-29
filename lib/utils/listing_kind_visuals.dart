import 'package:flutter/material.dart';
import '../config/module_palette.dart';

abstract final class ListingKindVisuals {
  static Color accentOf(String listingType) => ModulePalette.forListingKind(listingType).accent;

  static LinearGradient gradientOf(String listingType) => ModulePalette.forListingKind(listingType).gradient;

  static String labelOf(String listingType) => switch (listingType) {
        'Stay' => 'STAY',
        'Taxi' => 'TAXI',
        'Plot' => 'PLOT',
        'Job' => 'JOB',
        _ => 'ROOM',
      };
}
