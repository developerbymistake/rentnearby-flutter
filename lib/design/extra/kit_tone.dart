import 'package:flutter/material.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/design_colors.dart';

class KitTone {
  const KitTone({
    required this.accent,
    required this.accentDark,
    required this.tint,
    required this.gradient,
    required this.glow,
  });

  final Color accent;
  final Color accentDark;
  final Color tint;
  final LinearGradient gradient;
  final Color glow;

  factory KitTone.fromColor(Color c) => KitTone(
        accent: c,
        accentDark: c,
        tint: DesignColors.tint(c, Alpha.tint),
        gradient: LinearGradient(
          colors: [Color.lerp(c, DesignColors.surface, 0.16)!, c],
          begin: DesignGradients.begin,
          end: DesignGradients.end,
        ),
        glow: c,
      );

  factory KitTone.solid(Color c, {Color? tint}) => KitTone(
        accent: c,
        accentDark: c,
        tint: tint ?? DesignColors.tint(c, Alpha.tint),
        gradient: LinearGradient(
          colors: [c, c],
          begin: DesignGradients.begin,
          end: DesignGradients.end,
        ),
        glow: c,
      );

  factory KitTone.fromAccent(Color c) => KitTone.solid(c);

  static const KitTone stay = KitTone(
    accent: DesignColors.lunchStart,
    accentDark: DesignColors.lunchEnd,
    tint: DesignColors.offerTint,
    gradient: DesignGradients.lunch,
    glow: DesignColors.lunchEnd,
  );

  static const KitTone trip = stay;

  static const KitTone taxi = KitTone(
    accent: DesignColors.breakfastStart,
    accentDark: DesignColors.sunriseDeepEnd,
    tint: DesignColors.attentionTint,
    gradient: DesignGradients.breakfast,
    glow: DesignColors.sunriseDeep,
  );

  static const KitTone jobs = KitTone(
    accent: DesignColors.dinnerStart,
    accentDark: DesignColors.dinnerEnd,
    tint: DesignColors.statusOwnSoft,
    gradient: DesignGradients.dinner,
    glow: DesignColors.dinnerEnd,
  );

  static const KitTone rose = KitTone(
    accent: DesignColors.snackStart,
    accentDark: DesignColors.roseDeep,
    tint: DesignColors.savedTint,
    gradient: DesignGradients.snack,
    glow: DesignColors.roseDeep,
  );

  static const KitTone danger = KitTone(
    accent: DesignColors.roseDeepStart,
    accentDark: DesignColors.roseDeep,
    tint: DesignColors.savedTint,
    gradient: DesignGradients.snack,
    glow: DesignColors.roseDeep,
  );

  static const KitTone seeker = stay;

  static const KitTone stayOwner = KitTone(
    accent: DesignColors.sunriseDeep,
    accentDark: DesignColors.sunriseDeepEnd,
    tint: DesignColors.attentionTint,
    gradient: DesignGradients.stayOwnerDeep,
    glow: DesignColors.sunriseDeepEnd,
  );

  static const KitTone taxiDriver = KitTone(
    accent: DesignColors.roseDeepStart,
    accentDark: DesignColors.roseDeep,
    tint: DesignColors.savedTint,
    gradient: DesignGradients.taxiDriverDeep,
    glow: DesignColors.roseDeep,
  );

  static const KitTone brand = KitTone(
    accent: DesignColors.primary,
    accentDark: DesignColors.primary,
    tint: DesignColors.primaryTint,
    gradient: LinearGradient(
      colors: [DesignColors.primary, DesignColors.navAccentEnd],
      begin: DesignGradients.begin,
      end: DesignGradients.end,
    ),
    glow: DesignColors.primary,
  );
}

abstract final class KitMetrics {
  static const double gutter = 20;
  static const double sectionGap = 24;
  static const double cardGap = 12;
  static const double buttonHeight = 48;
  static const double buttonRadiusValue = 24;
  static const double touch = 44;
  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(buttonRadiusValue));
  static const BorderRadius tileSmall = BorderRadius.all(Radius.circular(12));
  static const BorderRadius photo = BorderRadius.all(Radius.circular(16));
}
