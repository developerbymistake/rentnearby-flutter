import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

// Content of one guide card; TripGuideView puts title, body, art and tone on the sheet.
class TripGuideFrame extends StatelessWidget {
  const TripGuideFrame({super.key, required this.title, required this.body, required this.asset, required this.child, this.tone});

  static int builds = 0;

  final String title;
  final String body;
  final String asset;
  final Widget child;
  final ListingTone? tone;

  @override
  Widget build(BuildContext context) {
    builds++;
    return child;
  }
}

class TripGuideSheetButton extends StatelessWidget {
  const TripGuideSheetButton({super.key, required this.label, required this.tone, this.onTap, this.primary = true, this.loading = false});

  final String label;
  final ListingTone tone;
  final VoidCallback? onTap;
  final bool primary;
  final bool loading;

  static const BorderRadius _primaryRadius =
      BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(8));

  @override
  Widget build(BuildContext context) {
    final live = onTap != null && !loading;
    return Semantics(
      button: true,
      enabled: live,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        enabled: live,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: live ? onTap : null,
          child: Opacity(
            opacity: onTap == null && !loading ? 0.5 : 1,
            child: Container(
              constraints: BoxConstraints(minHeight: 52, minWidth: double.infinity),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              alignment: Alignment.center,
              decoration: primary
                  ? BoxDecoration(
                      borderRadius: _primaryRadius,
                      gradient: tone.gradient,
                      boxShadow: [BoxShadow(color: tone.shadow.withValues(alpha: Alpha.half), offset: const Offset(1.1, 6), blurRadius: 14)],
                    )
                  : BoxDecoration(color: DesignColors.surface, borderRadius: BorderRadius.circular(18), boxShadow: Ink3D.softShadow),
              child: loading
                  ? KitDots(color: primary ? DesignColors.textInverse : tone.text)
                  : Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ink3D.text(primary ? 17 : 16, FontWeight.w700, primary ? DesignColors.textInverse : tone.text)),
            ),
          ),
        ),
      ),
    );
  }
}

class TripGuideLink extends StatelessWidget {
  const TripGuideLink({super.key, required this.label, this.onTap, this.color});

  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  widthFactor: 1,
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, color ?? Ink3D.grey)),
                ),
              ),
            ),
          ),
        ),
      );
}
