import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';

class PlanCycleOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? price;
  final String? perMonth;
  final bool best;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final String? unavailableText;
  final VoidCallback? onRetry;

  const PlanCycleOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.perMonth,
    required this.best,
    required this.selected,
    required this.onTap,
    required this.accent,
    this.unavailableText,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final dur = KitMotion.reduce(context) ? Duration.zero : const Duration(milliseconds: 250);
    final fgTitle = selected ? DesignColors.surface : DesignColors.textStrong;
    final fgSub = selected ? DesignColors.whiteHigh : TypeTokens.secondary;
    return Stack(clipBehavior: Clip.none, children: [
      PressScale(
        child: AnimatedContainer(
          duration: dur,
          curve: Curves.fastOutSlowIn,
          decoration: BoxDecoration(
            color: selected ? accent : DesignColors.surface,
            borderRadius: CardRadius.tile,
            boxShadow: selected ? ShadowTokens.elev3 : ShadowTokens.elev1,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: CardRadius.tile,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashColor: selected ? DesignColors.whiteSoft : DesignColors.splash,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  _radio(dur),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeTokens.style(14, FontWeight.w600, color: fgTitle, letterSpacing: 0.2)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TypeTokens.style(11, FontWeight.w500, color: fgSub)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: _priceColumn(fgTitle, fgSub)),
                ]),
              ),
            ),
          ),
        ),
      ),
      if (best)
        Positioned(
          top: -9,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: const BoxDecoration(color: DesignColors.goodDeep, borderRadius: CardRadius.pill),
            child: Text('BEST VALUE',
                style: TypeTokens.style(10, FontWeight.w700, color: DesignColors.surface, chip: true)),
          ),
        ),
    ]);
  }

  Widget _radio(Duration dur) => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: DesignColors.surface,
          border: Border.all(
              color: selected ? DesignColors.surface : DesignColors.borderStrong, width: 2),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: selected ? 1 : 0),
          duration: dur,
          curve: Curves.easeOutBack,
          builder: (context, v, _) => Transform.scale(
            scale: v.clamp(0.0, 1.2),
            child: Container(
                width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: accent)),
          ),
        ),
      );

  Widget _priceColumn(Color fg, Color soft) {
    final unavailable = unavailableText;
    if (unavailable != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Text(unavailable,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypeTokens.style(12, FontWeight.w600, color: soft)),
        if (onRetry != null)
          InkWell(
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Retry',
                  style: TypeTokens.style(12, FontWeight.w700,
                      color: selected ? DesignColors.surface : DesignColors.primary)),
            ),
          ),
      ]);
    }
    final p = price;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      if (p == null)
        const TemplatePlaceholder(width: 60, height: 18, radius: 6)
      else
        Text(p,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypeTokens.style(16, FontWeight.w700, color: fg)),
      if (p != null && perMonth != null && perMonth!.isNotEmpty)
        Text(perMonth!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TypeTokens.style(11, FontWeight.w500, color: soft)),
    ]);
  }
}
