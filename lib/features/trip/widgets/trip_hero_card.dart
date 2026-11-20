import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../trip_strings_overview.dart';

class TripHeroCard extends StatelessWidget {
  const TripHeroCard({
    super.key,
    required this.tone,
    required this.asset,
    required this.title,
    this.chip,
    this.chipWidget,
    required this.line,
    this.button,
    this.buttonKey,
    required this.onTap,
    this.highlight = false,
    this.compact = false,
  });

  final bool highlight;
  final ListingTone tone;
  final String asset;
  final String title;
  final String? chip;
  final Widget? chipWidget;
  final String line;
  final String? button;
  final Key? buttonKey;
  final VoidCallback? onTap;
  final bool compact;

  static const double _buttonFont = 13.5;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final circle = compact ? 80.0 : (narrow ? 84.0 : 100.0);
    final art = compact ? 52.0 : (narrow ? 52.0 : 62.0);
    final c = chip;
    final b = button;
    final card = Container(
      constraints: BoxConstraints(minHeight: DS.s(compact ? 112 : 140)),
      padding: compact ? DS.insets(l: 12, t: 12, r: 18, b: 12) : DS.insets(l: 16, t: 16, r: 20, b: 16),
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: DS.br(CardRadius.hero),
        border: highlight ? Border.all(color: DesignColors.surface, width: DS.s(2.5)) : null,
        boxShadow: highlight ? tone.glow(blur: 22, dy: 8) : tone.glow(blur: 14, dy: 6),
      ),
      child: Row(
        children: [
          Container(
            width: DS.s(circle),
            height: DS.s(circle),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: DesignColors.whiteSoft, shape: BoxShape.circle),
            child: Art3D(asset: asset, size: art, shadowBlur: 4, shadowOffset: const Offset(3, 5)),
          ),
          Gap.h(16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: DS.s(narrow || compact ? 0 : 24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(title, maxLines: 1, style: Ink3D.text(compact ? 18 : 21, FontWeight.w700, DesignColors.textInverse, height: 1.2)),
                        ),
                      ),
                      if (chipWidget != null) ...[Gap.h(10), chipWidget!],
                      if (chipWidget == null && c != null) ...[
                        Gap.h(10),
                        Container(
                          padding: DS.sym(h: 12, v: 3),
                          decoration: BoxDecoration(color: DesignColors.tint(DesignColors.surface, Alpha.v30), borderRadius: DS.circular(10)),
                          child: Text(c, style: Ink3D.text(12.5, FontWeight.w700, DesignColors.textInverse, height: 1.5)),
                        ),
                      ],
                    ],
                  ),
                  Gap.v(compact ? 6 : 8),
                  Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, DesignColors.textInverse, height: 1.45)),
                  if (b != null) ...[
                    Gap.v(8),
                    Tap3D(
                      tapKey: buttonKey,
                      onTap: onTap,
                      child: Container(
                        constraints: BoxConstraints(minHeight: DS.s(compact ? 36 : 40)),
                        padding: DS.sym(h: compact ? 18 : 22),
                        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(22), boxShadow: DS.shadows(Ink3D.whiteBtn)),
                        child: Center(
                          widthFactor: 1,
                          child: Text(b,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Ink3D.text(compact ? 13 : _buttonFont, FontWeight.w700, onTap == null ? Ink3D.grey : tone.text)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return highlight ? Semantics(label: TripStringsOverview.nextLabel(title), child: card) : card;
  }
}
