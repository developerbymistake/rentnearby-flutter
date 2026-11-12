import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/template_tokens.dart';
import '../tokens/type_tokens.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';

class KitDots extends StatefulWidget {
  const KitDots({super.key, this.color = DesignColors.onPrimary, this.size = 7});

  final Color color;
  final double size;

  @override
  State<KitDots> createState() => _KitDotsState();
}

class _KitDotsState extends State<KitDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (KitMotion.reduce(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size / 3),
              child: Transform.scale(
                scale: 0.6 + 0.4 * (1 - ((_c.value * 3 - i) % 3).clamp(0.0, 1.0)),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = KitTone.brand,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = KitMetrics.buttonHeight,
    this.trailingArrow = false,
    this.compact = false,
    this.heroCorner = false,
    this.scaleLabel = true,
  });

  final bool compact;
  final bool heroCorner;
  final bool scaleLabel;
  final String label;
  final VoidCallback? onPressed;
  final KitTone tone;
  final Widget? icon;
  final bool loading;
  final bool expand;
  final double height;
  final bool trailingArrow;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final h = height < KitMetrics.touch ? KitMetrics.touch : height;
    final radius = heroCorner ? CardRadius.hero : KitMetrics.buttonRadius;
    final content = loading
        ? const KitDots()
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 8)],
              Flexible(
                child: _label(
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(compact ? 13 : 16, FontWeight.w600,
                        color: enabled ? DesignColors.onPrimary : DesignColors.textDisabled,
                        letterSpacing: 0.2),
                  ),
                  scaleLabel,
                ),
              ),
              if (trailingArrow) ...[
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded,
                    size: 18,
                    color: enabled ? DesignColors.onPrimary : DesignColors.textDisabled),
              ],
            ],
          );
    final btn = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.fastOutSlowIn,
      height: h,
      decoration: BoxDecoration(
        gradient: enabled || loading ? tone.gradient : null,
        color: enabled || loading ? null : DesignColors.surfaceMuted,
        borderRadius: radius,
        boxShadow: enabled || loading ? ShadowTokens.glow(tone.glow) : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          splashColor: TemplateTokens.white24,
          highlightColor: Colors.transparent,
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
            child: Center(widthFactor: expand ? null : 1, child: content),
          ),
        ),
      ),
    );
    return PressScale(
      enabled: enabled,
      child: expand ? SizedBox(width: double.infinity, child: btn) : btn,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.tone = KitTone.brand,
    this.icon,
    this.expand = true,
    this.height = KitMetrics.buttonHeight,
    this.neutral = false,
    this.compact = false,
    this.scaleLabel = true,
  });

  final bool compact;
  final bool scaleLabel;

  final String label;
  final VoidCallback? onPressed;
  final KitTone tone;
  final Widget? icon;
  final bool expand;
  final double height;
  final bool neutral;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = !enabled
        ? DesignColors.textDisabled
        : neutral
            ? DesignColors.textGrey
            : tone.accentDark;
    final h = height < KitMetrics.touch ? KitMetrics.touch : height;
    final btn = Container(
      height: h,
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: KitMetrics.buttonRadius,
        border: Border.all(
            color: neutral ? DesignColors.borderStrong : color, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: KitMetrics.buttonRadius,
          splashColor: DesignColors.tint(color, Alpha.soft),
          highlightColor: Colors.transparent,
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
            child: Center(
              widthFactor: expand ? null : 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 8)],
                  Flexible(
                    child: _label(
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(compact ? 13 : 16, FontWeight.w600,
                              color: color, letterSpacing: 0.2)),
                      scaleLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return PressScale(
      enabled: enabled,
      child: expand ? SizedBox(width: double.infinity, child: btn) : btn,
    );
  }
}

class PillAction extends StatelessWidget {
  const PillAction({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = KitTone.brand,
    this.icon,
    this.filled = false,
    this.height = 40,
    this.maxWidth,
  });

  final double? maxWidth;

  final String label;
  final VoidCallback? onTap;
  final KitTone tone;
  final Widget? icon;
  final bool filled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final fg = !enabled
        ? DesignColors.textDisabled
        : filled
            ? DesignColors.onPrimary
            : tone.accentDark;
    const radius = BorderRadius.all(Radius.circular(999));
    return PressScale(
      enabled: enabled,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: KitMetrics.touch, maxWidth: maxWidth ?? double.infinity),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              gradient: filled && enabled ? tone.gradient : null,
              color: filled && enabled ? null : DesignColors.surface,
              borderRadius: radius,
              border: filled ? null : Border.all(color: fg, width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: radius,
                splashColor: filled
                    ? TemplateTokens.white24
                    : DesignColors.tint(tone.accentDark, Alpha.soft),
                highlightColor: Colors.transparent,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[icon!, const SizedBox(width: 6)],
                      Flexible(
                        child: _label(
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.style(12, FontWeight.w700,
                                  color: fg, letterSpacing: 0.27)),
                          true,
                        ),
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

class TextLink extends StatelessWidget {
  const TextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.tone = KitTone.brand,
    this.trailingArrow = false,
  });

  final String label;
  final VoidCallback? onTap;
  final KitTone tone;
  final bool trailingArrow;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? DesignColors.textDisabled : tone.accentDark;
    return InkWell(
      onTap: onTap,
      borderRadius: KitMetrics.photo,
      splashColor: DesignColors.tint(color, Alpha.soft),
      highlightColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: KitMetrics.touch),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TypeTokens.style(14, FontWeight.w600,
                      color: color, letterSpacing: 0.2)),
              if (trailingArrow) ...[
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 16, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class KitRoundButton extends StatelessWidget {
  const KitRoundButton({super.key, required this.icon, required this.onTap, this.size = 40, this.color = FitnessAppTheme.grey});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: SizedBox(
        width: KitMetrics.touch,
        height: KitMetrics.touch,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: DesignColors.surfaceAlt,
              shape: BoxShape.circle,
              boxShadow: [ShadowTokens.tint(DesignColors.primary, const ShadowSpec(0.4, Offset(4, 4), 8))],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                splashColor: DesignColors.tint(DesignColors.primary, Alpha.soft),
                highlightColor: Colors.transparent,
                onTap: onTap,
                child: Icon(icon, size: 24, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _label(Widget text, bool scale) =>
    scale ? FittedBox(fit: BoxFit.scaleDown, child: text) : text;

class ButtonPair extends StatelessWidget {
  const ButtonPair({super.key, required this.first, required this.second, this.stackAbove = 1.15, this.gap = 12});

  final Widget first;
  final Widget second;
  final double stackAbove;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 > stackAbove;
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, SizedBox(height: gap), second],
      );
    }
    return Row(children: [Expanded(child: first), SizedBox(width: gap), Expanded(child: second)]);
  }
}

class KitChoiceChip extends StatelessWidget {
  const KitChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.tone = KitTone.brand,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final KitTone tone;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? DesignColors.onPrimary : DesignColors.textPrimary;
    return PressScale(
      enabled: onTap != null,
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
                splashColor: selected ? TemplateTokens.white24 : DesignColors.tint(tone.accentDark, Alpha.soft),
                highlightColor: Colors.transparent,
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[icon!, const SizedBox(width: 6)],
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

class KitChainChip extends StatelessWidget {
  const KitChainChip({
    super.key,
    required this.label,
    required this.number,
    required this.current,
    required this.done,
    required this.onTap,
    this.tone = KitTone.brand,
  });

  final String label;
  final int number;
  final bool current;
  final bool done;
  final VoidCallback? onTap;
  final KitTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone.accent;
    final fg = current ? DesignColors.onPrimary : (done ? accent : DesignColors.textGrey);
    return PressScale(
      enabled: onTap != null,
      child: AnimatedContainer(
        duration: KitMotion.reduce(context) ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        decoration: BoxDecoration(
          gradient: current ? tone.gradient : null,
          color: current ? null : DesignColors.surface,
          borderRadius: CardRadius.pill,
          border: Border.all(color: current || done ? accent : DesignColors.divider),
          boxShadow: current ? ShadowTokens.glow(tone.glow) : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: CardRadius.pill,
            splashColor: DesignColors.tint(tone.accentDark, Alpha.soft),
            highlightColor: Colors.transparent,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: KitMotion.reduce(context) ? Duration.zero : const Duration(milliseconds: 250),
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: current ? DesignColors.surface : (done ? accent : DesignColors.scaffold),
                        shape: BoxShape.circle,
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, size: 14, color: DesignColors.surface)
                          : Text('$number',
                              style: TypeTokens.style(11, FontWeight.w700,
                                  color: current ? accent : DesignColors.textMuted)),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(12, FontWeight.w600, letterSpacing: 0.27, color: fg)),
                    ),
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
