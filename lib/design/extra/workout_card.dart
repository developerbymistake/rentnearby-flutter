import 'package:bakhli/design/tokens/design_scale.dart';
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
    this.gradient,
    this.actionLabel,
    this.extra = const [],
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
  final Gradient? gradient;
  final String? actionLabel;
  final List<Widget> extra;

  static double get overhang => DS.s(30);

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
    final margin = DS.insets(l: this.margin.left, t: this.margin.top, r: this.margin.right, b: this.margin.bottom);
    final minHeight = DS.s(this.minHeight);
    final artRaw = narrow ? 88.0 : 104.0;
    final artSize = DS.s(artRaw);
    final textRight = artSize - DS.s(8);
    final action = actionLabel;
    final hasAction = action != null;
    final keepInner = extra.isNotEmpty;
    final edge = hasAction ? DS.s(2) : 0.0;
    final hasArrow = trailing == WorkoutTrailing.arrow && !hasAction;
    final hasRing = trailing == WorkoutTrailing.ring;
    final hasDots = trailing == WorkoutTrailing.dots && dotCount > 1;
    final dotsWidth = hasDots ? DS.s(18) + (dotCount - 1) * (DS.s(7) + DS.gh(5)) : 0.0;
    final rowRight = hasArrow || hasRing ? DS.s(80) : (hasDots ? dotsWidth + DS.s(12) : 0.0);
    final artBottom = artSize - overhang;
    final floor = hasRing
        ? artBottom + DS.s(4 + 64 + 18)
        : (hasArrow ? artBottom + DS.s(46 + 18 - 12) : (hasAction ? artBottom + DS.s(8 + WorkoutActionPill.height + 20) : 0.0));
    final scaler = MediaQuery.textScalerOf(context);
    final inner = MediaQuery.sizeOf(context).width - margin.horizontal - DS.s(44);
    final eyebrowStyle = Ink3D.text(13, FontWeight.w500, white.withValues(alpha: 0.88));
    final titleBase = Ink3D.text(narrow ? 20 : 22, FontWeight.w700, white, height: 1.15);
    final subBase = Ink3D.text(13, FontWeight.w400, white.withValues(alpha: 0.92), height: 1.35);
    var y = DS.s(20);
    double rightAt(double top, double below) => top < artBottom ? textRight : below;
    final eyebrowRight = rightAt(y, 0);
    if (eyebrow.isNotEmpty) y += KitText.heightOf(eyebrow, eyebrowStyle, scaler, inner - eyebrowRight, 2) + DS.s(6);
    final titleRight = rightAt(y, 0);
    final titleStyle = KitText.wholeWords(title, titleBase, inner - titleRight, scaler);
    y += KitText.heightOf(title, titleStyle, scaler, inner - titleRight, 3);
    final subRight = rightAt(y + DS.s(6), hasRing || (ctaLabel == null && chips.isEmpty) ? rowRight : 0);
    final subStyle = KitText.wholeWords(subtitle, subBase, inner - subRight, scaler);
    if (subtitle.isNotEmpty) y += DS.s(6) + KitText.heightOf(subtitle, subStyle, scaler, inner - subRight, 8);
    final extraRight = rightAt(y + DS.s(10), 0) + edge;
    final subInRow = hasAction && !keepInner;
    Widget quiet(Widget w) => keepInner ? ExcludeSemantics(child: w) : w;

    final card = DecoratedBox(
      decoration: BoxDecoration(borderRadius: DS.br(radius), gradient: gradient ?? tone.gradient, boxShadow: tone.glow()),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight > floor ? minHeight : floor),
        child: Padding(
          padding: DS.insets(l: 22, t: 20, r: hasAction ? 20 : 22, b: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: hasAction ? MainAxisAlignment.end : MainAxisAlignment.center,
            children: [
              if (eyebrow.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(right: eyebrowRight + edge, bottom: DS.s(6)),
                  child: quiet(StarText(eyebrow, maxLines: 2, style: eyebrowStyle)),
                ),
              Padding(
                padding: EdgeInsets.only(right: titleRight + edge),
                child: quiet(Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: titleStyle)),
              ),
              if (subtitle.isNotEmpty && !subInRow)
                Padding(
                  padding: EdgeInsets.only(top: DS.s(6), right: subRight + edge),
                  child: quiet(Text(subtitle, maxLines: 8, overflow: TextOverflow.ellipsis, style: subStyle)),
                ),
              for (final row in extra) Padding(padding: EdgeInsets.only(right: extraRight), child: row),
              if (hasAction)
                Padding(
                  padding: EdgeInsets.only(top: DS.s(keepInner ? 14 : 6)),
                  child: quiet(_ActionRow(
                    subtitle: subInRow ? subtitle : '',
                    subStyle: subStyle,
                    subRight: subRight + edge,
                    label: action,
                    tone: tone,
                  )),
                ),
              if (chips.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: DS.s(14), right: rowRight),
                  child: Wrap(
                    spacing: DS.gh(8),
                    runSpacing: DS.gv(8),
                    children: [
                      for (final c in chips)
                        DecoratedBox(
                          decoration: BoxDecoration(color: white.withValues(alpha: 0.22), borderRadius: DS.circular(12)),
                          child: Padding(
                            padding: DS.sym(h: 12, v: 5),
                            child: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, white)),
                          ),
                        ),
                    ],
                  ),
                ),
              if (ctaLabel != null)
                Padding(
                  padding: EdgeInsets.only(top: DS.s(14), right: rowRight),
                  child: Row(
                    children: [
                      Flexible(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: white,
                            borderRadius: DS.circular(22),
                            boxShadow: DS.shadows(const [BoxShadow(color: Color(0x40000000), offset: Offset(1.1, 3), blurRadius: 6)]),
                          ),
                          child: Padding(
                            padding: DS.sym(h: 18, v: 9),
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
        fit: StackFit.passthrough,
        children: [
          SizedBox(width: double.infinity, child: card),
          Positioned(
            right: DS.s(14),
            top: -overhang,
            child: IgnorePointer(
              child: quiet(Art3D(asset: art, size: artRaw, halo: artRaw + 6, haloColor: white.withValues(alpha: 0.2), haloDy: 6, shadowAlpha: 0.3)),
            ),
          ),
          if (hasArrow) Positioned(right: DS.s(20), bottom: DS.s(18), child: RoundGoButton(color: tone.button, size: 46)),
          if (hasRing) Positioned(right: DS.s(20), bottom: DS.s(18), child: RingBadge(progress: progress, fill: tone.g2, size: 64)),
          if (hasDots)
            Positioned(
              right: DS.s(24),
              bottom: DS.s(24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < dotCount; i++)
                    Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : DS.gh(5)),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: DS.s(i == dotIndex ? 18 : 7),
                        height: DS.s(7),
                        decoration: BoxDecoration(color: i == dotIndex ? white : white.withValues(alpha: 0.5), borderRadius: DS.circular(4)),
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
    return Semantics(label: semanticsLabel, button: onTap != null, container: true, excludeSemantics: !keepInner, child: body);
  }
}

class WorkoutActionPill extends StatelessWidget {
  const WorkoutActionPill({super.key, required this.label, required this.tone});

  final String label;
  final ListingTone tone;

  static const double height = 46;
  static const double _left = 22;
  static const double _gap = 14;
  static const double _go = 36;
  static const double _right = 5;

  static TextStyle styleOf(ListingTone tone) => Ink3D.text(14, FontWeight.w700, tone.button);

  static double widthOf(BuildContext context, String label, ListingTone tone) =>
      DS.s(_left + _gap + _go + _right) +
      KitText.widthOf(label, DefaultTextStyle.of(context).style.merge(styleOf(tone)), MediaQuery.textScalerOf(context));

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(height)),
      padding: DS.insets(l: _left, r: _right),
      decoration: BoxDecoration(color: white, borderRadius: DS.circular(height / 2), boxShadow: DS.shadows(Ink3D.whiteBtn)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: styleOf(tone))),
          SizedBox(width: DS.s(_gap)),
          Container(
            width: DS.s(_go),
            height: DS.s(_go),
            decoration: BoxDecoration(color: tone.button, shape: BoxShape.circle),
            child: Icon(Icons.arrow_forward, color: white, size: DS.s(20)),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.subtitle, required this.subStyle, required this.subRight, required this.label, required this.tone});

  final String subtitle;
  final TextStyle subStyle;
  final double subRight;
  final String label;
  final ListingTone tone;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final pill = WorkoutActionPill(label: label, tone: tone);
        final atRight = Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: c.maxWidth), child: pill),
        );
        if (subtitle.isEmpty) return atRight;
        final gap = DS.s(12);
        final subWidth = KitText.widthOf(subtitle, DefaultTextStyle.of(context).style.merge(subStyle), MediaQuery.textScalerOf(context));
        if (subWidth + gap + WorkoutActionPill.widthOf(context, label, tone) <= c.maxWidth) {
          return Row(
            children: [
              Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: subStyle)),
              SizedBox(width: gap),
              pill,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(right: subRight),
              child: Text(subtitle, maxLines: 8, overflow: TextOverflow.ellipsis, style: subStyle),
            ),
            SizedBox(height: gap),
            atRight,
          ],
        );
      },
    );
  }
}
