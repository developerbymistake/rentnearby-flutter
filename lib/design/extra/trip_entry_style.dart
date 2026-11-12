import 'package:bakhli/design/template/fitness_app_theme.dart';
import 'package:flutter/material.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'travel_palette.dart';
import 'trip_kit.dart';

class TripEntryStyle {
  TripEntryStyle._();

  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[TravelPalette.skyStart, TravelPalette.skyEnd],
  );
  static const LinearGradient sunrise = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[TravelPalette.sunriseStart, TravelPalette.sunriseEnd],
  );
  static const LinearGradient rose = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[TravelPalette.roseStart, TravelPalette.roseEnd],
  );

  static const Color accent = FitnessAppTheme.nearlyDarkBlue;
  static const Color surface = FitnessAppTheme.background;
  static const Color skyTint = DesignColors.offerTintMid;
  static const Color sunriseTint = DesignColors.askedTintMid;
  static const Color roseTint = DesignColors.snackTintMid;
  static const Color border = DesignColors.borderSoft;

  static const BorderRadius cardRadius = CardRadius.tile;
  static const BorderRadius headerRadius = CardRadius.header;
  static const BorderRadius ringRadius = CardRadius.tile;

  static const List<BoxShadow> cardShadow = ShadowTokens.elev2;
  static const List<BoxShadow> skyShadow = DesignShadows.lunch;
  static const List<BoxShadow> topShadow = DesignShadows.top;
}

class TripGradientButton extends StatelessWidget {
  const TripGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 52,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool isLoading;

  @override
  Widget build(BuildContext context) => PrimaryButton(
        label: label,
        onPressed: onPressed,
        loading: isLoading,
        height: height,
        tone: KitTone.trip,
      );
}

class TripEntryEmpty extends StatelessWidget {
  const TripEntryEmpty({
    super.key,
    this.icon,
    this.iconAsset,
    required this.title,
    required this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  final IconData? icon;
  final String? iconAsset;
  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: TripKitStateView(
        carded: true,
        padding: const EdgeInsets.all(20),
        leading: iconAsset != null
            ? Image.asset(iconAsset!, width: 40, height: 40, fit: BoxFit.contain)
            : Icon(icon, size: 34, color: KitTone.trip.accentDark),
        title: title,
        subtitle: subtitle,
        actionLabel: onAction != null ? (actionLabel ?? 'Retry') : null,
        onAction: onAction,
      ),
    );
  }
}
