import 'package:flutter/material.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/card_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import '../tokens/type_tokens.dart';
import 'buttons_kit.dart';
import 'kit_tone.dart';
import 'module_header.dart';
import 'motion_kit.dart';
import 'template_motion.dart';
import 'travel_icon.dart';
import 'trip_kit.dart';

class RepliesTone {
  RepliesTone._();
  static const Color accent = DesignColors.primary;
  static const Color accentSurface = DesignColors.primaryFaint;
  static const Color good = DesignColors.goodDeep;
  static const Color goodSurface = DesignColors.infoSoft;
  static const Color warn = DesignColors.warnDeep;
  static const Color warnSurface = DesignColors.statusAskedSoft;
  static const Color bad = DesignColors.roseDeep;
  static const Color badSurface = DesignColors.statusSavedSoft;
  static const Color chip = FitnessAppTheme.spacer;
  static const Color shadow = DesignColors.shadowCool;
  static const LinearGradient gradient = DesignGradients.lunch;
}

class RepliesCard extends StatelessWidget {
  const RepliesCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color = DesignColors.surface});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;

  static const BorderRadius radius = CardRadius.tile;

  @override
  Widget build(BuildContext context) => TripKitSurface(color: color, padding: padding, onTap: onTap, child: child);
}

class RepliesButton extends StatelessWidget {
  const RepliesButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false, this.height = 48, this.color = DesignColors.primary, this.iconAsset});
  final Color color;
  final String? iconAsset;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) => PrimaryButton(
        label: label,
        onPressed: onPressed,
        loading: loading,
        height: height,
        scaleLabel: true,
        tone: tripToneForColor(color),
        icon: iconAsset != null
            ? TravelIcon(iconAsset!, size: 20)
            : icon != null
                ? Icon(icon, size: 18, color: DesignColors.onPrimary)
                : null,
      );
}

class RepliesIconCircle extends StatelessWidget {
  const RepliesIconCircle({super.key, required this.icon, this.color = DesignColors.primary, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: DesignColors.tint(color, Alpha.tint), shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.5, color: color),
      );
}

class RepliesEmpty extends StatelessWidget {
  const RepliesEmpty({super.key, required this.asset, required this.title, this.subtitle, this.onRetry, this.retryLabel = 'Retry'});
  final String retryLabel;
  final String asset;
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: TripKitStateView(
        carded: true,
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        leading: Image.asset(asset, width: 40, height: 40, fit: BoxFit.contain),
        title: title,
        subtitle: subtitle,
        actionLabel: onRetry != null ? retryLabel : null,
        onAction: onRetry,
      ),
    );
  }
}

class RepliesHeader extends StatelessWidget {
  const RepliesHeader({super.key, required this.onBack, required this.child, this.iconAsset = 'assets/images/design/fitness_app/runner.png'});
  final VoidCallback onBack;
  final Widget child;
  final String iconAsset;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion(
      value: ModuleHeader.lightIcons,
      child: Container(
        decoration: BoxDecoration(
          gradient: KitTone.trip.gradient,
          borderRadius: CardRadius.header,
          boxShadow: ShadowTokens.glow(KitTone.trip.glow),
        ),
        margin: const EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.fromLTRB(8, top + ModuleHeader.paddingTop, 16, ModuleHeader.paddingBottom),
        child: Row(
          children: [
            PressScale(
              child: SizedBox(
                width: KitMetrics.touch,
                height: KitMetrics.touch,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  splashColor: DesignColors.whiteSoft,
                  highlightColor: Colors.transparent,
                  onTap: onBack,
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: DesignColors.textInverse),
                ),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(child: child),
            const SizedBox(width: 8),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: DesignColors.tint(DesignColors.surfaceAlt, Alpha.soft), shape: BoxShape.circle),
              child: Padding(padding: const EdgeInsets.all(8), child: Image.asset(iconAsset)),
            ),
          ],
        ),
      ),
    );
  }
}

class RepliesChip extends StatelessWidget {
  const RepliesChip({super.key, required this.label, required this.onTap, this.icon, this.iconAsset, this.color = DesignColors.primary, this.height = 44, this.fontSize = 12.5});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? iconAsset;
  final Color color;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final c = onTap == null ? DesignColors.textDisabled : color;
    return PressScale(
      enabled: onTap != null,
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        decoration: BoxDecoration(color: DesignColors.tint(c, Alpha.tint), borderRadius: CardRadius.pill),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: CardRadius.pill,
            splashColor: DesignColors.tint(c, Alpha.soft),
            highlightColor: Colors.transparent,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (iconAsset != null) ...[
                    TravelIcon(iconAsset!, size: 18),
                    const SizedBox(width: 6),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 16, color: c),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label, maxLines: 1, style: TypeTokens.style(fontSize, FontWeight.w600, color: c, letterSpacing: 0.2)),
                    ),
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

class RepliesEntrance extends StatefulWidget {
  const RepliesEntrance({super.key, required this.child, this.offset = 30, this.animate = true});
  final Widget child;
  final double offset;
  final bool animate;

  @override
  State<RepliesEntrance> createState() => _RepliesEntranceState();
}

class _RepliesEntranceState extends State<RepliesEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(duration: const Duration(milliseconds: 600), vsync: this, value: widget.animate ? 0 : 1);
  late final Animation<double> _animation = templateInterval(_controller, 0, 1);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      TemplateEntrance(animation: _animation, animationController: _controller, offset: widget.offset, child: widget.child);
}

class RepliesInfoStrip extends StatelessWidget {
  const RepliesInfoStrip({super.key, required this.child, this.iconAsset, this.color = RepliesTone.accentSurface, this.iconSize = 18});
  final Widget child;
  final String? iconAsset;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: color, borderRadius: CardRadius.chip),
        child: Row(
          children: [
            if (iconAsset != null) ...[TravelIcon(iconAsset!, size: iconSize), const SizedBox(width: 8)],
            Expanded(child: child),
          ],
        ),
      );
}

class RepliesDialogButton extends StatelessWidget {
  const RepliesDialogButton({super.key, required this.label, required this.onPressed, this.color = DesignColors.primary});
  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64),
        child: PrimaryButton(label: label, onPressed: onPressed, expand: false, compact: true, tone: tripToneForColor(color)),
      );
}
