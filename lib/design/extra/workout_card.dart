import 'package:flutter/material.dart';

import 'art_3d.dart';
import 'meals_card_v.dart';
import 'motion_kit.dart';
import 'wide_card.dart';

enum WorkoutTrailing { none, arrow, ring, dots }

class WorkoutCard extends StatelessWidget {
  const WorkoutCard({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.eyebrow = '',
    this.subtitle = '',
    this.ctaLabel,
    this.chips = const [],
    this.trailing = WorkoutTrailing.none,
    this.progress = 0,
    this.dotCount = 2,
    this.dotIndex = 0,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 18),
    this.minHeight = 138,
    this.semanticsLabel,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String eyebrow;
  final String subtitle;
  final String? ctaLabel;
  final List<String> chips;
  final WorkoutTrailing trailing;
  final double progress;
  final int dotCount;
  final int dotIndex;
  final VoidCallback? onTap;
  final EdgeInsets margin;
  final double minHeight;
  final String? semanticsLabel;

  static const double overhang = 30;

  static const BorderRadius radius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(68),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final artSize = narrow ? 88.0 : 104.0;
    final textRight = artSize - 8;
    final hasArrow = trailing == WorkoutTrailing.arrow;
    final hasRing = trailing == WorkoutTrailing.ring;
    final hasDots = trailing == WorkoutTrailing.dots && dotCount > 1;
    final dotsWidth = hasDots ? 18.0 + (dotCount - 1) * 12 : 0.0;
    final rowRight = hasArrow || hasRing ? 80.0 : (hasDots ? dotsWidth + 12 : 0.0);
    final artBottom = artSize - overhang;
    final floor = hasRing ? artBottom + 4 + 64 + 18 : (hasArrow ? artBottom + 46 + 18 - 12 : 0.0);
    final scaler = MediaQuery.textScalerOf(context);
    final inner = MediaQuery.sizeOf(context).width - margin.horizontal - 44;
    final eyebrowStyle = Ink3D.text(13, FontWeight.w500, white.withValues(alpha: 0.88));
    final titleBase = Ink3D.text(narrow ? 20 : 22, FontWeight.w700, white, height: 1.15);
    final subBase = Ink3D.text(13, FontWeight.w400, white.withValues(alpha: 0.92), height: 1.35);
    var y = 20.0;
    double rightAt(double top, double below) => top < artBottom ? textRight : below;
    final eyebrowRight = rightAt(y, 0);
    if (eyebrow.isNotEmpty) y += KitText.heightOf(eyebrow, eyebrowStyle, scaler, inner - eyebrowRight, 2) + 6;
    final titleRight = rightAt(y, 0);
    final titleStyle = KitText.wholeWords(title, titleBase, inner - titleRight, scaler);
    y += KitText.heightOf(title, titleStyle, scaler, inner - titleRight, 3);
    final subRight = rightAt(y + 6, hasRing || (ctaLabel == null && chips.isEmpty) ? rowRight : 0);
    final subStyle = KitText.wholeWords(subtitle, subBase, inner - subRight, scaler);

    final card = DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, gradient: tone.gradient, boxShadow: tone.glow()),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight > floor ? minHeight : floor),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(right: eyebrowRight, bottom: 6),
                  child: StarText(eyebrow, maxLines: 2, style: eyebrowStyle),
                ),
              Padding(
                padding: EdgeInsets.only(right: titleRight),
                child: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: titleStyle),
              ),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 6, right: subRight),
                  child: Text(subtitle, maxLines: 8, overflow: TextOverflow.ellipsis, style: subStyle),
                ),
              if (chips.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 14, right: rowRight),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in chips)
                        DecoratedBox(
                          decoration: BoxDecoration(color: white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, white)),
                          ),
                        ),
                    ],
                  ),
                ),
              if (ctaLabel != null)
                Padding(
                  padding: EdgeInsets.only(top: 14, right: rowRight),
                  child: Row(
                    children: [
                      Flexible(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(1.1, 3), blurRadius: 6)],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(ctaLabel!, maxLines: 1, style: Ink3D.text(14, FontWeight.w700, tone.button)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    Widget body = Padding(
      padding: margin.copyWith(top: margin.top + overhang),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(width: double.infinity, child: card),
          Positioned(
            right: 14,
            top: -overhang,
            child: IgnorePointer(
              child: Art3D(asset: art, size: artSize, halo: artSize + 6, haloColor: white.withValues(alpha: 0.2), haloDy: 6, shadowAlpha: 0.3),
            ),
          ),
          if (hasArrow) Positioned(right: 20, bottom: 18, child: RoundGoButton(color: tone.button, size: 46)),
          if (hasRing) Positioned(right: 20, bottom: 18, child: RingBadge(progress: progress, fill: tone.g2, size: 64)),
          if (hasDots)
            Positioned(
              right: 24,
              bottom: 24,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < dotCount; i++)
                    Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == dotIndex ? 18 : 7,
                        height: 7,
                        decoration: BoxDecoration(color: i == dotIndex ? white : white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
    if (onTap != null) {
      body = PressScale(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: body));
    }
    if (semanticsLabel == null) return body;
    return Semantics(label: semanticsLabel, button: onTap != null, container: true, excludeSemantics: true, child: body);
  }
}
