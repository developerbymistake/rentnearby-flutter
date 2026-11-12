import 'package:flutter/material.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'travel_icon.dart';
import 'travel_palette.dart';
import 'trip_kit.dart';

class PickKit {
  static const Color stay = DesignColors.lunchStart;
  static const Color stayDark = DesignColors.lunchEnd;
  static const Color stayTint = DesignColors.offerTint;
  static const LinearGradient stayGradient = DesignGradients.lunch;

  static const Color taxi = DesignColors.breakfastStart;
  static const Color taxiDark = DesignColors.sunriseDeepEnd;
  static const Color taxiTint = DesignColors.attentionTint;
  static const LinearGradient taxiGradient = DesignGradients.breakfast;

  static const Color trip = DesignColors.primary;
  static const Color tripDark = DesignColors.navAccentEnd;
  static const Color tripTint = DesignColors.primaryTint;
  static const LinearGradient tripGradient = DesignGradients.brand;

  static const Color good = DesignColors.goodDeep;
  static const Color goodDark = DesignColors.goodDeep;
  static const Color goodTint = DesignColors.infoTint;
  static const Color warn = DesignColors.warnDeep;
  static const Color warnTint = DesignColors.attentionTint;
  static const Color bad = DesignColors.roseDeep;
  static const Color badTint = DesignColors.savedTint;
  static const Color warmTint = DesignColors.askedTint;
  static const Color gold = TravelPalette.sunriseStart;

  static const BorderRadius cardRadius = CardRadius.tile;

  static List<BoxShadow> shadow(Color c) => ShadowTokens.glow(c);

  static List<BoxShadow> greyShadow() => ShadowTokens.elev2;

  static const List<String> hotelImages = [
    'assets/images/design/hotel/hotel_1.png',
    'assets/images/design/hotel/hotel_2.png',
    'assets/images/design/hotel/hotel_3.png',
    'assets/images/design/hotel/hotel_4.png',
    'assets/images/design/hotel/hotel_5.png',
  ];
  static const String userImage = 'assets/images/design/images/userImage.png';

  static String hotelImage(Object? key) => hotelImages[(key.hashCode & 0x7fffffff) % hotelImages.length];
}

class PickButton extends StatelessWidget {
  const PickButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.height = 52,
    this.gradient = PickKit.tripGradient,
    this.shadowColor = PickKit.trip,
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
        tone: identical(gradient, PickKit.tripGradient) ? KitTone.brand : tripToneOf(gradient, shadowColor),
      );
}

class PickChip extends StatelessWidget {
  const PickChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeColor = PickKit.trip,
    this.icon,
    this.padding,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;
  final IconData? icon;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) =>
      TripKitChip(label: label, selected: selected, onTap: onTap, color: activeColor, icon: icon, padding: padding);
}

class PickEmpty extends StatelessWidget {
  const PickEmpty({
    super.key,
    this.icon,
    this.asset,
    required this.title,
    required this.subtitle,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.gradient = PickKit.tripGradient,
    this.accent = PickKit.trip,
  });

  final IconData? icon;
  final String? asset;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final String retryLabel;
  final LinearGradient gradient;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tone = identical(gradient, PickKit.tripGradient) ? KitTone.brand : tripToneOf(gradient, accent);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: TripKitStateView(
          carded: true,
          tone: tone,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          leading: asset != null ? TravelIcon(asset!, size: 40) : Icon(icon, size: 34, color: tone.accentDark),
          title: title,
          subtitle: subtitle,
          actionLabel: onRetry != null ? retryLabel : null,
          onAction: onRetry,
        ),
      ),
    );
  }
}
