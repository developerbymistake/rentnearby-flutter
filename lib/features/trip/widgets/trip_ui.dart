import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

abstract final class TripUi {
  static const KitTone tone = KitTone.trip;

  static KitTone toneOf(Color c) => KitTone.fromColor(c);

  static KitTone fromGradient(Gradient? g) {
    if (g == KitTone.taxi.gradient) return KitTone.taxi;
    if (g == KitTone.stay.gradient) return KitTone.stay;
    return KitTone.trip;
  }

  static const Color warn = DesignColors.breakfastStart;
  static const Color warnTint = DesignColors.attentionTint;
  static const Color bad = DesignColors.snackEnd;
  static const Color badTint = DesignColors.savedTint;
  static const Color good = FitnessAppTheme.nearlyBlue;
  static const Color goodDark = FitnessAppTheme.nearlyDarkBlue;
  static const Color goodTint = DesignColors.infoTint;
  static const Color gold = DesignColors.breakfastStart;
  static const Color stay = DesignColors.lunchStart;
  static const Color stayTint = DesignColors.offerTint;
  static const Color taxi = DesignColors.breakfastStart;
  static const Color taxiDark = DesignColors.snackEnd;
  static const Color taxiTint = DesignColors.attentionTint;
  static const Color trip = FitnessAppTheme.nearlyDarkBlue;
  static const Color tripDark = DesignColors.dinnerEnd;
  static const Color tripTint = DesignColors.primaryTint;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: KitMetrics.gutter);
}

class TripButton extends StatelessWidget {
  const TripButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.height = KitMetrics.buttonHeight,
    this.color,
    this.tone,
    this.icon,
    this.iconAsset,
    this.outlined = false,
    this.expand = true,
    this.neutral = false,
    this.isLoading = false,
    this.gradient,
    this.shadowColor,
  });

  final bool isLoading;
  final Gradient? gradient;
  final Color? shadowColor;

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final double height;
  final Color? color;
  final KitTone? tone;
  final IconData? icon;
  final String? iconAsset;
  final bool outlined;
  final bool expand;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? (color != null ? TripUi.toneOf(color!) : TripUi.fromGradient(gradient));
    final Widget? ic = iconAsset != null
        ? TravelIcon(iconAsset!, size: 20)
        : icon != null
            ? Icon(icon, size: 18, color: outlined ? t.accentDark : DesignColors.onPrimary)
            : null;
    if (outlined) {
      return SecondaryButton(label: label, onPressed: onPressed, tone: t, icon: ic, expand: expand, height: height, neutral: neutral);
    }
    return PrimaryButton(label: label, onPressed: onPressed, tone: t, icon: ic, loading: loading || isLoading, expand: expand, height: height);
  }
}

class TripEmpty extends StatelessWidget {
  const TripEmpty({
    super.key,
    required this.title,
    this.subtitle,
    this.asset = TravelIcon.route,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.tone = KitTone.trip,
    this.error = false,
    this.padding = const EdgeInsets.fromLTRB(KitMetrics.gutter, 32, KitMetrics.gutter, 24),
  });

  final String title;
  final String? subtitle;
  final String asset;
  final VoidCallback? onRetry;
  final String retryLabel;
  final KitTone tone;
  final bool error;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => StateCard(
        title: title,
        message: subtitle,
        asset: asset,
        kit: tone,
        tone: error ? StateTone.error : StateTone.empty,
        actionLabel: onRetry == null ? null : retryLabel,
        onAction: onRetry,
        padding: padding,
      );
}

class TripSurface extends StatelessWidget {
  const TripSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = DesignColors.surface,
    this.shadow = ShadowTokens.elev2,
    this.radius = CardRadius.tile,
    this.borderColor,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final List<BoxShadow> shadow;
  final BorderRadius radius;
  final Color? borderColor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        boxShadow: shadow,
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
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
      child: onTap == null ? card : PressScale(child: card),
    );
  }
}

class TripActionChip extends StatelessWidget {
  const TripActionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconAsset,
    this.color,
    this.height = 40,
    this.filled = false,
    this.fontSize,
  });

  final double? fontSize;

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? iconAsset;
  final Color? color;
  final double height;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = color != null ? TripUi.toneOf(color!) : KitTone.trip;
    final Widget? ic = iconAsset != null
        ? TravelIcon(iconAsset!, size: 18)
        : icon != null
            ? Icon(icon, size: 16, color: filled ? DesignColors.onPrimary : t.accentDark)
            : null;
    return PillAction(label: label, onTap: onTap, tone: t, icon: ic, filled: filled, height: height);
  }
}

class TripNote extends StatelessWidget {
  const TripNote({super.key, required this.child, this.iconAsset, this.color = DesignColors.surfaceTint, this.iconSize = 18});

  final Widget child;
  final String? iconAsset;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: color, borderRadius: CardRadius.chip),
        child: Row(
          children: [
            if (iconAsset != null) ...[TravelIcon(iconAsset!, size: iconSize), const SizedBox(width: 8)],
            Expanded(child: child),
          ],
        ),
      );
}

class TripHeaderAction extends StatelessWidget {
  const TripHeaderAction({super.key, required this.label, required this.onTap, this.icon, this.solid = false});

  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(999));
    return PressScale(
      enabled: onTap != null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KitMetrics.touch, minWidth: KitMetrics.touch),
        child: Center(
          widthFactor: 1,
          child: Material(
            color: solid ? DesignColors.surface : DesignColors.whiteSoft,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: solid ? BorderSide.none : BorderSide(color: DesignColors.tint(DesignColors.surface, Alpha.half)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashColor: TemplateTokens.white24,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[TravelIcon(icon!, size: 18), const SizedBox(width: 6)],
                    Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TypeTokens.style(13, FontWeight.w700, color: solid ? ListingTone.indigo.text : DesignColors.textInverse, letterSpacing: 0.27))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TripChoiceChip extends StatelessWidget {
  const TripChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.activeColor,
    this.icon,
    this.iconAsset,
    this.padding,
    this.muted = false,
  });

  final bool muted;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final Color? activeColor;
  final IconData? icon;
  final String? iconAsset;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = TripUi.toneOf(activeColor ?? color ?? DesignColors.lunchEnd);
    final lit = selected && !muted;
    final fg = muted ? DesignColors.textMuted : (selected ? DesignColors.onPrimary : DesignColors.textPrimary);
    const radius = BorderRadius.all(Radius.circular(999));
    return PressScale(
      enabled: onTap != null && !muted,
      child: AnimatedContainer(
        duration: KitMotion.reduce(context) ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        constraints: const BoxConstraints(minHeight: KitMetrics.touch - 8),
        decoration: BoxDecoration(
          gradient: lit ? t.gradient : null,
          color: lit ? null : (muted ? DesignColors.scaffold : DesignColors.surface),
          borderRadius: radius,
          border: lit || muted ? null : Border.all(color: DesignColors.border),
          boxShadow: lit ? ShadowTokens.elev1 : const [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: lit ? TemplateTokens.white24 : DesignColors.splash,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconAsset != null) ...[TravelIcon(iconAsset!, size: 16), const SizedBox(width: 6)]
                  else if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeTokens.style(13, selected ? FontWeight.w700 : FontWeight.w500, color: fg, letterSpacing: 0.2)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
