import 'package:bakhli/design/template/fitness_app_theme.dart';
import 'package:flutter/material.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'travel_icon.dart';
import 'travel_palette.dart';
import 'trip_kit.dart';
class TripLook {
  static const Color accent = FitnessAppTheme.nearlyDarkBlue;
  static const Color accentDark = FitnessAppTheme.nearlyDarkBlue;
  static const Color accentLight = FitnessAppTheme.nearlyBlue;
  static const Color surface = DesignColors.primaryFaint;
  static const LinearGradient gradient = DesignGradients.lunch;

  static const List<BoxShadow> barShadow = DesignShadows.top;

  static const Color textDark = FitnessAppTheme.darkerText;
  static const Color textMedium = FitnessAppTheme.grey;
  static const Color textLight = FitnessAppTheme.lightText;
  static const Color textHint = FitnessAppTheme.deactivatedText;
  static const Color divider = FitnessAppTheme.spacer;
  static const Color scaffoldBg = FitnessAppTheme.background;
  static const Color cardBg = FitnessAppTheme.white;
  static const Color neutralChip = FitnessAppTheme.background;
  static const Color neutralChipText = FitnessAppTheme.grey;

  static const Color warning = TravelPalette.sunriseStart;
  static const Color warningText = DesignColors.warnDeep;
  static const Color warningSurface = DesignColors.statusAttentionSoft;
  static const Color error = TravelPalette.roseEnd;
  static const Color errorText = DesignColors.roseDeep;
  static const Color errorSurface = DesignColors.statusSavedSoft;
  static const Color success = FitnessAppTheme.nearlyBlue;
  static const Color successText = FitnessAppTheme.nearlyDarkBlue;
  static const Color successSurface = DesignColors.infoSoft;
  static const Color advance = TravelPalette.duskStart;
  static const Color advanceSurface = DesignColors.statusOwnSoft;
  static const Color booked = TravelPalette.skyEnd;
  static const Color bookedSurface = DesignColors.bookedSoft;
  static const Color shadow = DesignColors.shadowSoft;

  static const List<Color> dayColors = <Color>[
    FitnessAppTheme.nearlyBlue,
    TravelPalette.sunriseStart,
    TravelPalette.skyStart,
    TravelPalette.roseStart,
    TravelPalette.duskStart,
    FitnessAppTheme.nearlyDarkBlue,
  ];
  static Color dayColor(int day) => dayColors[(day - 1) % dayColors.length];

  static const BorderRadius cardRadius = CardRadius.tile;
  static const BorderRadius softRadius = CardRadius.tile;

  static List<BoxShadow> shadowFor(Color c) => ShadowTokens.glow(c);

  static BoxDecoration card({Color? color, Color? shadowColor, BorderRadius? radius}) => BoxDecoration(
        color: color ?? DesignColors.surface,
        borderRadius: radius ?? softRadius,
        boxShadow: shadowColor == null ? ShadowTokens.elev2 : <BoxShadow>[ShadowTokens.tint(shadowColor, ShadowSpec.elev2Spec)],
      );

  static BoxDecoration gradientCard(Color start, Color end, {BorderRadius? radius}) => BoxDecoration(
        gradient: LinearGradient(
            colors: <Color>[start, end], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: radius ?? cardRadius,
        boxShadow: shadowFor(end),
      );
}

class TripPlanButton extends StatelessWidget {
  const TripPlanButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.height = 52,
    this.gradient = TripLook.gradient,
    this.shadowColor = FitnessAppTheme.nearlyDarkBlue,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final double height;
  final Gradient gradient;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) => PrimaryButton(
        label: label,
        onPressed: onPressed,
        loading: isLoading,
        height: height,
        tone: identical(gradient, TripLook.gradient) ? KitTone.trip : tripToneOf(gradient, shadowColor),
      );
}

class TripPlanEmpty extends StatelessWidget {
  const TripPlanEmpty({
    super.key,
    this.icon,
    this.image,
    required this.title,
    required this.subtitle,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final IconData? icon;
  final String? image;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: TripKitStateView(
        carded: true,
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        leading: image != null
            ? TravelIcon(image!, size: 40)
            : Icon(icon, size: 34, color: KitTone.trip.accentDark),
        title: title,
        subtitle: subtitle,
        actionLabel: onRetry != null ? retryLabel : null,
        onAction: onRetry,
      ),
    );
  }
}
