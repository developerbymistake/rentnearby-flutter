import 'package:flutter/material.dart';
import '../template/fitness_app_theme.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/design_scale.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/template_tokens.dart';
import '../tokens/type_tokens.dart';
import 'kit_tone.dart';
import 'motion_kit.dart';

class KitDots extends StatefulWidget {
  const KitDots({super.key, this.color = DesignColors.onPrimary, this.size = 7, this.scaled = true});

  final Color color;
  final double size;
  final bool scaled;

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
    final dot = DS.s(widget.size, scaled: widget.scaled);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: dot / 3),
              child: Transform.scale(
                scale: 0.6 + 0.4 * (1 - ((_c.value * 3 - i) % 3).clamp(0.0, 1.0)),
                child: Container(
                  width: dot,
                  height: dot,
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
    this.scaled = true,
  });

  final bool scaled;
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
    final h = DS.s(height < KitMetrics.touch ? KitMetrics.touch : height, scaled: scaled);
    final radius = heroCorner ? DS.br(CardRadius.card, scaled: scaled) : DS.circular(KitMetrics.buttonRadiusValue, scaled: scaled);
    final content = loading
        ? KitDots(scaled: scaled)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, SizedBox(width: DS.s(8, scaled: scaled))],
              Flexible(
                child: _label(
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TypeTokens.style(compact ? 13 : 16, FontWeight.w600,
                        color: enabled ? DesignColors.onPrimary : DesignColors.textDisabled,
                        letterSpacing: 0.2, scaled: scaled),
                  ),
                  scaleLabel,
                ),
              ),
              if (trailingArrow) ...[
                SizedBox(width: DS.s(6, scaled: scaled)),
                Icon(Icons.arrow_forward_rounded,
                    size: DS.s(18, scaled: scaled),
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
        boxShadow: enabled || loading ? DS.shadows(ShadowTokens.glow(tone.glow), scaled: scaled) : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          splashColor: TemplateTokens.white24,
          highlightColor: Colors.transparent,
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: DS.s(compact ? 16 : 24, scaled: scaled)),
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
    this.scaled = true,
  });

  final bool scaled;
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
    final h = DS.s(height < KitMetrics.touch ? KitMetrics.touch : height, scaled: scaled);
    final bRadius = DS.circular(KitMetrics.buttonRadiusValue, scaled: scaled);
    final btn = Container(
      height: h,
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: bRadius,
        border: Border.all(
            color: neutral ? DesignColors.borderStrong : color, width: DS.s(1.5, scaled: scaled)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: bRadius,
          splashColor: DesignColors.tint(color, Alpha.soft),
          highlightColor: Colors.transparent,
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: DS.s(compact ? 16 : 24, scaled: scaled)),
            child: Center(
              widthFactor: expand ? null : 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, SizedBox(width: DS.s(8, scaled: scaled))],
                  Flexible(
                    child: _label(
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(compact ? 13 : 16, FontWeight.w600,
                              color: color, letterSpacing: 0.2, scaled: scaled)),
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
    this.compact = false,
    this.scaled = true,
  });

  final bool scaled;
  final bool compact;
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
        constraints: BoxConstraints(minHeight: DS.s(compact ? 34 : KitMetrics.touch, scaled: scaled), maxWidth: maxWidth ?? double.infinity),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            height: DS.s(compact ? 34 : height, scaled: scaled),
            decoration: BoxDecoration(
              gradient: filled && enabled ? tone.gradient : null,
              color: filled && enabled ? null : DesignColors.surface,
              borderRadius: radius,
              border: filled ? null : Border.all(color: fg, width: DS.s(1.5, scaled: scaled)),
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
                  padding: EdgeInsets.symmetric(horizontal: DS.s(compact ? 8 : 16, scaled: scaled)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[icon!, SizedBox(width: DS.s(compact ? 4 : 6, scaled: scaled))],
                      Flexible(
                        child: _label(
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.style(12, FontWeight.w700,
                                  color: fg, letterSpacing: 0.27, scaled: scaled)),
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
    this.scaled = true,
  });

  final bool scaled;
  final String label;
  final VoidCallback? onTap;
  final KitTone tone;
  final bool trailingArrow;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? DesignColors.textDisabled : tone.accentDark;
    return InkWell(
      onTap: onTap,
      borderRadius: DS.br(KitMetrics.photo, scaled: scaled),
      splashColor: DesignColors.tint(color, Alpha.soft),
      highlightColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch, scaled: scaled)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: DS.s(8, scaled: scaled)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TypeTokens.style(14, FontWeight.w600,
                        color: color, letterSpacing: 0.2, scaled: scaled)),
              ),
              if (trailingArrow) ...[
                SizedBox(width: DS.s(4, scaled: scaled)),
                Icon(Icons.arrow_forward_rounded, size: DS.s(16, scaled: scaled), color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class KitRoundButton extends StatelessWidget {
  const KitRoundButton({super.key, required this.icon, required this.onTap, this.size = 40, this.color = FitnessAppTheme.grey, this.scaled = true});

  final bool scaled;
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: SizedBox(
        width: DS.s(KitMetrics.touch, scaled: scaled),
        height: DS.s(KitMetrics.touch, scaled: scaled),
        child: Center(
          child: Container(
            width: DS.s(size, scaled: scaled),
            height: DS.s(size, scaled: scaled),
            decoration: BoxDecoration(
              color: DesignColors.surfaceAlt,
              shape: BoxShape.circle,
              boxShadow: DS.shadows([ShadowTokens.tint(DesignColors.primary, const ShadowSpec(0.4, Offset(4, 4), 8))], scaled: scaled),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                splashColor: DesignColors.tint(DesignColors.primary, Alpha.soft),
                highlightColor: Colors.transparent,
                onTap: onTap,
                child: Icon(icon, size: DS.s(24, scaled: scaled), color: color),
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
  const ButtonPair({super.key, required this.first, required this.second, this.stackAbove = 1.15, this.gap = 12, this.scaled = true});

  final bool scaled;
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
        children: [first, SizedBox(height: DS.gv(gap, scaled: scaled)), second],
      );
    }
    return Row(children: [Expanded(child: first), SizedBox(width: DS.gh(gap, scaled: scaled)), Expanded(child: second)]);
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
    this.scaled = true,
  });

  final bool scaled;
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
        constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch, scaled: scaled)),
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
              boxShadow: selected ? DS.shadows(ShadowTokens.glow(tone.glow), scaled: scaled) : const [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: CardRadius.pill,
                splashColor: selected ? TemplateTokens.white24 : DesignColors.tint(tone.accentDark, Alpha.soft),
                highlightColor: Colors.transparent,
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: DS.s(16, scaled: scaled), vertical: DS.s(9, scaled: scaled)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[icon!, SizedBox(width: DS.s(6, scaled: scaled))],
                      Flexible(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TypeTokens.style(13, FontWeight.w600, color: fg, letterSpacing: 0.2, scaled: scaled)),
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
    this.scaled = true,
  });

  final bool scaled;
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
          boxShadow: current ? DS.shadows(ShadowTokens.glow(tone.glow), scaled: scaled) : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: CardRadius.pill,
            splashColor: DesignColors.tint(tone.accentDark, Alpha.soft),
            highlightColor: Colors.transparent,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: DS.s(36, scaled: scaled)),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: DS.s(14, scaled: scaled), vertical: DS.s(6, scaled: scaled)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: KitMotion.reduce(context) ? Duration.zero : const Duration(milliseconds: 250),
                      width: DS.s(20, scaled: scaled),
                      height: DS.s(20, scaled: scaled),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: current ? DesignColors.surface : (done ? accent : DesignColors.scaffold),
                        shape: BoxShape.circle,
                      ),
                      child: done
                          ? Icon(Icons.check_rounded, size: DS.s(14, scaled: scaled), color: DesignColors.surface)
                          : Text('$number',
                              style: TypeTokens.style(11, FontWeight.w700, scaled: scaled,
                                  color: current ? accent : DesignColors.textMuted)),
                    ),
                    SizedBox(width: DS.s(6, scaled: scaled)),
                    Flexible(
                      child: Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(12, FontWeight.w600, letterSpacing: 0.27, color: fg, scaled: scaled)),
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
