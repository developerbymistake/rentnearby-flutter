import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/template_tokens.dart';
import '../tokens/type_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';
import 'travel_palette.dart';

KitTone tripToneOf(Gradient gradient, Color color) => gradient is LinearGradient
    ? KitTone(
        accent: color,
        accentDark: color,
        tint: DesignColors.tint(color, Alpha.tint),
        gradient: gradient,
        glow: color,
      )
    : KitTone.fromColor(color);

KitTone tripToneForColor(Color color) => color == DesignColors.primary ? KitTone.brand : KitTone.fromColor(color);

class TripKitSurface extends StatelessWidget {
  const TripKitSurface({
    super.key,
    required this.child,
    this.onTap,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.color = DesignColors.surface,
    this.radius = CardRadius.tile,
    this.shadow = ShadowTokens.elev2,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color color;
  final BorderRadius radius;
  final List<BoxShadow> shadow;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: radius, boxShadow: shadow),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: DesignColors.splash,
          highlightColor: Colors.transparent,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return Padding(
      padding: margin,
      child: onTap != null ? PressScale(child: card) : card,
    );
  }
}

class TripKitStateView extends StatelessWidget {
  const TripKitStateView({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.tone = KitTone.trip,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    this.carded = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final KitTone tone;
  final EdgeInsetsGeometry padding;
  final bool carded;

  @override
  Widget build(BuildContext context) {
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                DesignColors.tint(tone.accentDark, Alpha.soft),
                DesignColors.tint(tone.accentDark, Alpha.faint),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(child: leading),
        ),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.2)),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle!,
              textAlign: TextAlign.center,
              style: TypeTokens.style(14, FontWeight.w400, color: TypeTokens.secondary)),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          PrimaryButton(label: actionLabel!, onPressed: onAction, tone: tone, expand: false),
        ],
      ],
    );
    final content = carded
        ? TripKitSurface(padding: padding, child: SizedBox(width: double.infinity, child: body))
        : Padding(padding: padding, child: body);
    return EntranceOnce(
      child: LayoutBuilder(
        builder: (context, c) => c.hasBoundedHeight ? ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: [content]) : content,
      ),
    );
  }
}

class TripKit {
  static const LinearGradient sky = DesignGradients.lunch;

  static const BorderRadius cardRadius = CardRadius.tile;

  static const BorderRadius cardRadiusSmall = CardRadius.tile;

  static const String iconDir = 'assets/images/design/fitness_app/';

  static const LinearGradient scrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [DesignColors.scrimClear, DesignColors.scrimMid, DesignColors.scrimBlack],
    stops: [0.3, 0.55, 1],
  );

  static const LinearGradient scrimShort = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [DesignColors.scrimClear, DesignColors.scrimBlack],
    stops: [0.45, 1],
  );

  static BoxDecoration cardBox({
    BorderRadius radius = cardRadius,
    Gradient? gradient,
    Color? color,
    Color shadowColor = TravelPalette.skyEnd,
    Border? border,
  }) =>
      BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: radius,
        border: border,
        boxShadow: gradient == null ? ShadowTokens.elev2 : cardShadow(shadowColor),
      );

  static Widget iconBadge(String asset, {double size = 28, double image = 18}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: DesignColors.surface.withValues(alpha: Alpha.scrim), shape: BoxShape.circle),
        child: Image.asset('$iconDir$asset.png', width: image, height: image),
      );

  static Widget travelBadge(String assetPath, {double size = 28, double image = 18}) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: DesignColors.surface.withValues(alpha: Alpha.scrim), shape: BoxShape.circle),
        child: Image.asset(assetPath, width: image, height: image),
      );

  static const List<Color> dayColors = [
    TravelPalette.skyEnd,
    TravelPalette.roseEnd,
    TravelPalette.sunriseStart,
    TravelPalette.duskStart,
    FitnessAppTheme.nearlyBlue,
    TravelPalette.duskEnd,
  ];

  static Color dayColor(int day) => dayColors[(day - 1) % dayColors.length];

  static String hexOf(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  static List<BoxShadow> shadow({Color? color, double alpha = ShadowSpec.defaultAlpha, double blur = ShadowSpec.defaultBlur}) =>
      color == null && alpha == ShadowSpec.defaultAlpha
          ? ShadowTokens.elev2
          : [ShadowTokens.tint(color ?? DesignColors.textGrey, ShadowSpec.elev2Spec.scaled(alpha / ShadowSpec.defaultAlpha))];

  static List<BoxShadow> shadowOf(ShadowSpec spec, [Color? color]) =>
      [ShadowTokens.tint(color ?? DesignColors.textGrey, spec)];

  static List<BoxShadow> cardShadow([Color color = TravelPalette.skyEnd]) => ShadowTokens.glow(color);

  static TextStyle text(double size, {FontWeight weight = FontWeight.w500, Color color = DesignColors.textStrong}) =>
      TypeTokens.style(size, weight, color: color);
}

class TripKitChip extends StatelessWidget {
  const TripKitChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = TravelPalette.skyEnd,
    this.icon,
    this.iconAsset,
    this.padding,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;
  final String? iconAsset;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tone = tripToneForColor(color);
    final fg = selected ? DesignColors.onPrimary : DesignColors.textPrimary;
    return PressScale(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KitMetrics.touch),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.fastOutSlowIn,
            decoration: BoxDecoration(
              gradient: selected ? tone.gradient : null,
              color: selected ? null : DesignColors.chipBackground,
              borderRadius: CardRadius.pill,
              boxShadow: selected ? ShadowTokens.glow(tone.glow) : const [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: CardRadius.pill,
                splashColor: selected ? TemplateTokens.white24 : DesignColors.tint(color, Alpha.soft),
                highlightColor: Colors.transparent,
                onTap: onTap,
                child: Padding(
                  padding: padding ?? const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (iconAsset != null) ...[
                        Image.asset(iconAsset!, width: 16, height: 16),
                        const SizedBox(width: 6),
                      ] else if (icon != null) ...[
                        Icon(icon, size: 16, color: fg),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TypeTokens.style(13, FontWeight.w600, color: fg, letterSpacing: 0.2)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TripKitButton extends StatelessWidget {
  const TripKitButton({super.key, required this.label, required this.onPressed, this.height = 52});

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) =>
      PrimaryButton(label: label, onPressed: onPressed, tone: KitTone.trip, height: height);
}

class TripKitEmpty extends StatelessWidget {
  const TripKitEmpty({
    super.key,
    this.icon,
    required this.title,
    this.subtitle = '',
    this.onRetry,
    this.retryLabel = 'Retry',
    this.iconAsset,
    this.travelAsset,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  final String retryLabel;
  final String? iconAsset;
  final String? travelAsset;

  @override
  Widget build(BuildContext context) {
    return TripKitStateView(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
      leading: travelAsset != null
          ? Image.asset(travelAsset!, width: 40, height: 40)
          : iconAsset != null
              ? Image.asset('${TripKit.iconDir}$iconAsset.png', width: 40, height: 40)
              : Icon(icon ?? Icons.place_rounded, size: 34, color: KitTone.trip.accentDark),
      title: title,
      subtitle: subtitle,
      actionLabel: onRetry != null ? retryLabel : null,
      onAction: onRetry,
    );
  }
}
