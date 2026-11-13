import 'package:flutter/material.dart';
import '../config/module_palette.dart';
import '../design/design.dart';
import 'plan_badge_chip.dart';

class NearbyItemRow extends StatelessWidget {
  final String? thumbnailUrl;
  final String tag;
  final String title;
  final String subtitle;
  final String caption;
  final String value;
  final String unit;
  final ModulePalette palette;
  final IconData placeholderIcon;
  final String? placeholderAsset;
  final bool elevated;
  final bool isFeatured;
  final VoidCallback onTap;
  final Widget? trailing;
  final List<Widget>? actions;
  final Animation<double>? animation;
  final AnimationController? animationController;

  const NearbyItemRow({
    super.key,
    required this.thumbnailUrl,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.caption,
    required this.value,
    this.unit = '',
    this.palette = templateModulePalette,
    required this.placeholderIcon,
    required this.onTap,
    this.placeholderAsset,
    this.elevated = false,
    this.isFeatured = false,
    this.trailing,
    this.actions,
    this.animation,
    this.animationController,
  });

  static const double tile = 72;

  KitTone get _tone => KitTone(
        accent: palette.accent,
        accentDark: palette.accentDark,
        tint: palette.surface,
        gradient: palette.gradient,
        glow: palette.accentDark,
      );

  @override
  Widget build(BuildContext context) {
    final tone = _tone;
    final hasActions = actions != null && actions!.isNotEmpty;
    final card = ListRow(
      title: title,
      subtitle: subtitle,
      tag: tag,
      solidTag: true,
      rich: true,
      tagBadge: isFeatured
          ? FittedBox(fit: BoxFit.scaleDown, child: PlanBadgeChip(color: tone.accentDark, compact: false))
          : null,
      thumbnailUrl: thumbnailUrl,
      iconAsset: placeholderAsset ?? TravelIcon.stay,
      tone: tone,
      elevated: elevated,
      onTap: onTap,
      margin: elevated ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: KitMetrics.gutter, vertical: 6),
      trailing: _price(tone),
      footer: hasActions ? Row(children: [for (final a in actions!) Expanded(child: a)]) : null,
    );
    if (animation == null || animationController == null) return card;
    return TemplateEntrance(animation: animation!, animationController: animationController!, child: card);
  }

  Widget _price(KitTone tone) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 104),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (caption.isNotEmpty)
            Text(caption, maxLines: 1, style: TypeTokens.style(11, FontWeight.w700, color: TypeTokens.secondary, letterSpacing: 0.6)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: value),
                if (unit.isNotEmpty) TextSpan(text: unit, style: TypeTokens.style(11, FontWeight.w600, color: tone.accentDark)),
              ]),
              maxLines: 1,
              style: TypeTokens.style(18, FontWeight.w800, color: tone.accentDark),
            ),
          ),
          const SizedBox(height: 4),
          trailing ?? Icon(Icons.arrow_forward, size: 18, color: tone.accentDark),
        ],
      ),
    );
  }
}

class NearbyRowAction extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const NearbyRowAction({super.key, required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        splashColor: DesignColors.splash,
        highlightColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KitMetrics.touch),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            icon,
            const SizedBox(width: 6),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeTokens.style(12, FontWeight.w600, color: color)),
            ),
          ]),
        ),
      );
}
