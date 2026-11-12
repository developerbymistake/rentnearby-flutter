import 'package:flutter/material.dart';
import '../../config/module_palette.dart';
import '../../design/design.dart';

class TripStatusColors {
  static const Color shortlisted = DesignColors.textSecondary;
  static const Color waiting = DesignColors.warning;
  static const Color waitingSurface = DesignColors.warningSoft;
  static const Color confirmedByYou = DesignColors.dinnerEnd;
  static const Color confirmedByYouSurface = DesignColors.primarySoft;
  static const Color both = DesignColors.success;
  static const Color bothSurface = DesignColors.successSoft;
  static const Color advance = DesignColors.statusBooked;
  static const Color advanceSurface = DesignColors.successSoft;
  static const Color failed = DesignColors.error;
  static const Color failedSurface = DesignColors.errorSoft;
  static const Color booked = DesignColors.statusConfirmed;
  static const Color bookedSurface = DesignColors.primarySoft;
}

class TripColors {
  static const Color accent = DesignColors.primary;
  static const Color accentDark = DesignColors.dinnerEnd;
  static const Color accentLight = DesignColors.primaryLight;
  static const Color surface = DesignColors.primarySoft;
  static const LinearGradient gradient = DesignGradients.brand;
  static const ModulePalette palette = templateTripPalette;
  static const List<Color> dayColors = [
    DesignColors.primary,
    DesignColors.primaryLight,
    DesignColors.hotelStart,
    DesignColors.breakfastStart,
    DesignColors.lunchStart,
    DesignColors.statusSaved,
  ];

  static Color dayColor(int day) => dayColors[(day - 1) % dayColors.length];
}
