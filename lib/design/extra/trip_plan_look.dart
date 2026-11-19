import 'package:bakhli/design/template/fitness_app_theme.dart';
import 'package:flutter/material.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/design_scale.dart';
import '../tokens/shadow_tokens.dart';
import 'art_3d.dart';
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

  static const Color dayIndigo = Color(0xFF738AE6);
  static const Color dayOrange = Color(0xFFFFC371);
  static const Color dayCyan = Color(0xFF4FC3F7);
  static const List<Color> dayColors = <Color>[dayIndigo, dayOrange, dayCyan];
  static Color dayColor(int day) => dayColors[(day - 1) % dayColors.length];

  static const Color rail = Color(0xFFB5BBEA);
  static const Color disabledFill = Color(0xFFC9CDD6);
  static const Color badText = Color(0xFFB83A40);
  static const Color mutedText = Color(0xFF6B6B6B);
  static const Color cardShadowInk = Color(0xFF3A5160);
  static const Color ink = Color(0xFF17262A);
  static const Color headerGlow = Color(0xFF5C5EDD);
  static const Color mapLand = Color(0xFFE7EFDD);
  static const Color mapRouteDay2 = Color(0xFFFF8A3D);

  static const List<BoxShadow> cardShadowSoft = <BoxShadow>[BoxShadow(color: Color(0x383A5160), offset: Offset(1.1, 1.1), blurRadius: 10)];
  static const List<BoxShadow> dayCardShadow = <BoxShadow>[BoxShadow(color: Color(0x403A5160), offset: Offset(1.1, 1.1), blurRadius: 12)];
  static const List<BoxShadow> headerShadow = <BoxShadow>[BoxShadow(color: Color(0x475C5EDD), offset: Offset(0, 8), blurRadius: 18)];
  static const List<BoxShadow> barShadowUp = Ink3D.topEdge;
  static const List<BoxShadow> whiteBtnShadow = Ink3D.whiteBtn;
  static const List<BoxShadow> pillShadow = <BoxShadow>[BoxShadow(color: Color(0x735C5EDD), offset: Offset(1.1, 8), blurRadius: 12)];
  static const List<BoxShadow> sectionShadow = <BoxShadow>[BoxShadow(color: Color(0x595C5EDD), offset: Offset(1.1, 4), blurRadius: 14)];
  static const List<BoxShadow> chipOnShadow = <BoxShadow>[BoxShadow(color: Color(0x4D5C5EDD), offset: Offset(0, 4), blurRadius: 8)];
  static const List<BoxShadow> chipOffShadow = <BoxShadow>[BoxShadow(color: Color(0x1F000000), offset: Offset(0, 2), blurRadius: 6)];

  static const BorderRadius cardRadius = CardRadius.tile;
  static const BorderRadius softRadius = CardRadius.tile;

  static List<BoxShadow> shadowFor(Color c) => ShadowTokens.glow(c);

  static BoxDecoration card({Color? color, Color? shadowColor, BorderRadius? radius}) => BoxDecoration(
        color: color ?? DesignColors.surface,
        borderRadius: DS.br(radius ?? softRadius),
        boxShadow: DS.shadows(shadowColor == null ? ShadowTokens.elev2 : <BoxShadow>[ShadowTokens.tint(shadowColor, ShadowSpec.elev2Spec)]),
      );

  static BoxDecoration gradientCard(Color start, Color end, {BorderRadius? radius}) => BoxDecoration(
        gradient: LinearGradient(
            colors: <Color>[start, end], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: DS.br(radius ?? cardRadius),
        boxShadow: DS.shadows(shadowFor(end)),
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
      padding: EdgeInsets.fromLTRB(DS.s(24), DS.gv(40), DS.s(24), 0),
      child: TripKitStateView(
        carded: true,
        padding: DS.insets(l: 20, t: 24, r: 20, b: 20),
        leading: image != null
            ? TravelIcon(image!, size: 40)
            : Icon(icon, size: DS.s(34), color: KitTone.trip.accentDark),
        title: title,
        subtitle: subtitle,
        actionLabel: onRetry != null ? retryLabel : null,
        onAction: onRetry,
      ),
    );
  }
}
