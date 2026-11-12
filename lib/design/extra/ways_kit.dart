import 'package:flutter/material.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/type_tokens.dart';
import '../tokens/template_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';

class WaysKit {
  WaysKit._();

  static const BorderRadius chipRadius = CardRadius.tile;
  static const BorderRadius pillRadius = KitMetrics.buttonRadius;

  static const List<BoxShadow> topShadow = DesignShadows.top;

  static TextStyle title(double size, {Color color = DesignColors.textStrong, FontWeight weight = FontWeight.w700}) =>
      TypeTokens.style(size, weight, color: color, letterSpacing: 0.2);

  static TextStyle caption(double size, {Color color = DesignColors.textSecondary, FontWeight weight = FontWeight.w400}) =>
      TypeTokens.style(size, weight, color: color, letterSpacing: 0.2);

  static Animation<double> topBar(AnimationController c) => Tween<double>(begin: 0, end: 1)
      .animate(CurvedAnimation(parent: c, curve: const Interval(0, 0.5, curve: Curves.fastOutSlowIn)));
}

class WaysTopBar extends StatelessWidget {
  const WaysTopBar({super.key, required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (KitMotion.reduce(context)) return child;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => FadeTransition(
        opacity: animation,
        child: Transform(
          transform: Matrix4.translationValues(0.0, 30 * (1.0 - animation.value), 0.0),
          child: child,
        ),
      ),
    );
  }
}

/// Button frame for call sites that need a minimum height (not a fixed one),
/// several label lines or a caller-chosen font size. Same pieces as
/// PrimaryButton / SecondaryButton: tone gradient, glow, button radius,
/// PressScale, disabled colours.
class KitFlexButton extends StatelessWidget {
  const KitFlexButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = KitTone.taxi,
    this.filled = true,
    this.icon,
    this.minHeight = 44,
    this.fontSize = 13,
    this.maxLines = 1,
    this.busy = false,
    this.shrink = false,
    this.scaleLabel = false,
    this.borderColor,
    this.glowColor,
    this.gradient,
    this.foreground,
  });

  final String label;
  final VoidCallback? onPressed;
  final KitTone tone;
  final bool filled;
  final Widget? icon;
  final double minHeight;
  final double fontSize;
  final int maxLines;
  final bool busy;
  final bool shrink;
  final bool scaleLabel;
  final Color? borderColor;
  final Color? glowColor;
  final Gradient? gradient;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final live = onPressed != null || busy;
    final fg = !live
        ? DesignColors.textDisabled
        : filled
            ? (foreground ?? DesignColors.onPrimary)
            : (foreground ?? tone.accentDark);
    final h = minHeight < KitMetrics.touch ? KitMetrics.touch : minHeight;
    final text = Text(
      label,
      maxLines: maxLines,
      textAlign: TextAlign.center,
      overflow: scaleLabel ? TextOverflow.visible : TextOverflow.ellipsis,
      style: TypeTokens.style(fontSize, FontWeight.w600, color: fg, letterSpacing: 0.2),
    );
    final content = busy
        ? KitDots(color: fg, size: 6)
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 6)],
              Flexible(child: scaleLabel ? FittedBox(fit: BoxFit.scaleDown, child: text) : text),
            ],
          );
    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: shrink ? content : Center(child: content),
    );
    return PressScale(
      enabled: enabled,
      child: Container(
        constraints: BoxConstraints(minHeight: h),
        decoration: BoxDecoration(
          gradient: filled && live ? (gradient ?? tone.gradient) : null,
          color: filled ? (live ? null : DesignColors.surfaceMuted) : DesignColors.surface,
          borderRadius: KitMetrics.buttonRadius,
          border: filled
              ? null
              : Border.all(color: !live ? DesignColors.border : (borderColor ?? tone.accentDark), width: 1.5),
          boxShadow: filled && live ? ShadowTokens.glow(glowColor ?? tone.glow) : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: KitMetrics.buttonRadius,
            splashColor: filled ? TemplateTokens.white24 : DesignColors.tint(tone.accentDark, Alpha.soft),
            highlightColor: Colors.transparent,
            onTap: enabled ? onPressed : null,
            child: inner,
          ),
        ),
      ),
    );
  }
}

class WaysOutlineButton extends StatelessWidget {
  const WaysOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 44,
    this.fontSize = 13,
    this.maxLines = 1,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double height;
  final double fontSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return KitFlexButton(
      label: label,
      onPressed: onPressed,
      filled: false,
      icon: icon,
      minHeight: height,
      fontSize: fontSize,
      maxLines: maxLines,
      shrink: true,
    );
  }
}

class WaysFilledButton extends StatelessWidget {
  const WaysFilledButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 44,
    this.fontSize = 13,
    this.gradient = DesignGradients.breakfast,
    this.shadowColor = DesignColors.sunriseDeep,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final double height;
  final double fontSize;
  final Gradient gradient;
  final Color shadowColor;

  @override
  Widget build(BuildContext context) {
    return KitFlexButton(
      label: label,
      onPressed: onPressed,
      icon: icon,
      minHeight: height,
      fontSize: fontSize,
      gradient: gradient,
      glowColor: shadowColor,
      shrink: true,
      scaleLabel: true,
    );
  }
}

class WaysBanner extends StatelessWidget {
  const WaysBanner({super.key, required this.icon, required this.text, this.trailing});

  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(color: DesignColors.warningSoft, borderRadius: KitMetrics.tileSmall),
      child: Row(children: [
        Icon(icon, size: 18, color: DesignColors.warnDeep),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: WaysKit.caption(12, color: DesignColors.warnDeep, weight: FontWeight.w600)),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}
