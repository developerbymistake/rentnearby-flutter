import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

enum StayEnquiryButtonKind { primary, positive, negative, plain }

class StayEnquiryButton extends StatelessWidget {
  const StayEnquiryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = StayEnquiryButtonKind.plain,
    this.icon,
    this.iconAsset,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final StayEnquiryButtonKind kind;
  final IconData? icon;
  final String? iconAsset;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final filled = kind == StayEnquiryButtonKind.primary || kind == StayEnquiryButtonKind.positive;
    final Gradient? gradient = switch (kind) {
      StayEnquiryButtonKind.primary => KitTone.stay.gradient,
      StayEnquiryButtonKind.positive => KitTone.brand.gradient,
      _ => null,
    };
    final Color glow = kind == StayEnquiryButtonKind.positive ? KitTone.brand.glow : KitTone.stay.glow;
    final Color accent = kind == StayEnquiryButtonKind.negative ? DesignColors.error : DesignColors.primary;
    final Color fg = !onTapOrBusy
        ? DesignColors.textDisabled
        : filled
            ? DesignColors.onPrimary
            : accent;
    final Color? border = filled
        ? null
        : kind == StayEnquiryButtonKind.negative
            ? DesignColors.error
            : DesignColors.divider;
    const radius = CardRadius.pill;
    return PressScale(
      enabled: enabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: filled && onTapOrBusy ? gradient : null,
          color: filled && onTapOrBusy ? null : (filled ? DesignColors.surfaceMuted : DesignColors.surface),
          borderRadius: radius,
          border: border != null ? Border.all(color: onTapOrBusy ? border : DesignColors.divider, width: 1.5) : null,
          boxShadow: filled && onTapOrBusy
              ? ShadowTokens.glow(glow)
              : (kind == StayEnquiryButtonKind.plain && onTapOrBusy ? ShadowTokens.elev1 : null),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: radius,
            splashColor: filled ? TemplateTokens.white24 : DesignColors.tint(accent, Alpha.soft),
            highlightColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(minHeight: KitMetrics.touch, minWidth: KitMetrics.touch),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (busy)
                  KitDots(color: fg, size: 5)
                else ...[
                  if (iconAsset != null) ...[TravelIcon(iconAsset!, size: 18), const SizedBox(width: 6)]
                  else if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                  Flexible(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeTokens.style(13, FontWeight.w600, color: fg, letterSpacing: 0.2)),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  bool get onTapOrBusy => onTap != null || busy;
}
