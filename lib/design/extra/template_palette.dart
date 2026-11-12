import 'package:bakhli/config/module_palette.dart';
import '../tokens/design_colors.dart';
import '../tokens/module_tokens.dart';

const ModulePalette templateModulePalette = ModulePalette(
  accent: DesignColors.primary,
  accentDark: DesignColors.primary,
  accentLight: DesignColors.primaryLight,
  surface: DesignColors.scaffold,
  gradient: DesignGradients.brand,
);

const ModulePalette templateStayPalette = ModulePalette(
  accent: DesignColors.hotelStart,
  accentDark: DesignColors.hotelEnd,
  accentLight: DesignColors.accentTeal,
  surface: DesignColors.successSoft,
  gradient: DesignGradients.hotel,
);

const ModulePalette templateJobsPalette = ModulePalette(
  accent: DesignColors.dinnerStart,
  accentDark: DesignColors.dinnerEnd,
  accentLight: DesignColors.ringLight,
  surface: DesignColors.statusOwnSoft,
  gradient: DesignGradients.dinner,
);

const ModulePalette templateTaxiPalette = ModulePalette(
  accent: DesignColors.breakfastStart,
  accentDark: DesignColors.snackEnd,
  accentLight: DesignColors.breakfastEnd,
  surface: DesignColors.statusAttentionSoft,
  gradient: DesignGradients.breakfast,
);

const ModulePalette templateTripPalette = ModulePalette(
  accent: DesignColors.primary,
  accentDark: DesignColors.dinnerEnd,
  accentLight: DesignColors.primaryLight,
  surface: DesignColors.primarySoft,
  gradient: DesignGradients.brand,
);

ModulePalette modulePaletteOf(ModuleTokens t) => ModulePalette(
      accent: t.accent,
      accentDark: t.accentDark,
      accentLight: t.accentLight,
      surface: t.surface,
      gradient: t.gradient,
    );
