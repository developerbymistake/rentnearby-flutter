import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'pill_buttons_3d.dart';
import 'skeleton_3d.dart';
import '../tokens/design_scale.dart';

class PlanInk {
  const PlanInk._();

  static const Color good = Color(0xFF2E7D32);
  static const Color bad = Color(0xFFD93F47);
  static const Color warn = Color(0xFFB9770E);
  static const Color muted = Color(0xFF767676);
  static const Color label = Color(0xFF4A6572);
  static const Color headRow = Color(0xFFF2F3F8);
  static const Color line = Color(0xFFEEF0F4);
  static const Color number = Color(0xFF9A9A9A);
  static const Color copy = Color(0xFF6A6A6A);
  static const Color bone = Color(0xFFE6E8EF);

  static const Color statusGood = Color(0xFF2EA050);
  static const Color statusBad = Color(0xFFD93F47);
  static const Color statusWarn = Color(0xFFE69114);
  static const Color statusGrey = Color(0xFF8C92A0);

  static const LinearGradient check = LinearGradient(colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static List<BoxShadow> get cardSoft => [BoxShadow(color: Color(0x409E9E9E), offset: DS.shadowOffset(const Offset(1.1, 1.1)), blurRadius: DS.shadowBlur(10))];
  static List<BoxShadow> get whiteButton => [BoxShadow(color: Color(0x669E9E9E), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(10))];
  static List<BoxShadow> get onCardButton => [BoxShadow(color: Color(0x33000000), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(8))];
  static List<BoxShadow> get barShadow => [BoxShadow(color: Color(0x599E9E9E), offset: DS.shadowOffset(const Offset(0, -2)), blurRadius: DS.shadowBlur(16))];
  static List<BoxShadow> get sheetShadow => [BoxShadow(color: Color(0x33000000), offset: DS.shadowOffset(const Offset(0, -4)), blurRadius: DS.shadowBlur(24))];
  static List<BoxShadow> get pillShadow => [BoxShadow(color: Color(0x2E000000), offset: DS.shadowOffset(const Offset(2, 3)), blurRadius: DS.shadowBlur(6))];
  static const Color scrim = Color(0x80141828);
  static const Color footStrip = Color(0x1C000000);
  static const Color onCardFill = Color(0x33FFFFFF);
  static const Color onCardRing = Color(0xBFFFFFFF);
  static const Color pillFill = Color(0x42FFFFFF);
  static const Color testPill = Color(0x29000000);
}

class PlanLook {
  const PlanLook._();

  static ListingPalette paletteOf(String? featureKey) => switch (featureKey) {
        'Stay' => ListingPalette.forest,
        'Taxi' => ListingPalette.coral,
        _ => ListingPalette.indigo,
      };

  static ListingTone toneOf(String? featureKey) => switch (featureKey) {
        'Stay' => ListingTone.forest,
        'Taxi' => ListingTone.coral,
        _ => ListingTone.indigo,
      };

  static Color pageOf(String? featureKey) => paletteOf(featureKey).page;

  static ListingTone cycleTone(String? featureKey, int index) {
    final last = featureKey == 'Taxi' ? ListingTone.cA : ListingTone.cE;
    return [ListingTone.cB, ListingTone.cF, last][index % 3];
  }

  static ListingTone get warmTone => ListingTone.cF;

  static double narrowness(BuildContext context) => MediaQuery.sizeOf(context).width;
}

BorderRadius get _barButtonRadius => BorderRadius.only(
    topLeft: Radius.circular(DS.radius(20)), topRight: Radius.circular(DS.radius(20)), bottomRight: Radius.circular(DS.radius(20)), bottomLeft: Radius.circular(DS.radius(8)));

class PlanBarButton extends StatelessWidget {
  const PlanBarButton({super.key, required this.tone, required this.label, required this.onTap, this.white = false, this.loading = false, this.width});

  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;
  final bool white;
  final bool loading;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null && !loading;
    final fg = white ? tone.text : Colors.white;
    final body = Container(
      width: width == null ? double.infinity : DS.s(width!),
      constraints: BoxConstraints(minHeight: DS.s(54)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(16), vertical: DS.s(8)),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: _barButtonRadius,
        color: white ? Colors.white : null,
        gradient: white ? null : tone.gradient,
        boxShadow: !on && !loading ? null : (white ? PlanInk.whiteButton : DS.shadows(Form3D.glow(tone, offset: const Offset(1.1, 6)))),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (loading) ...[
          SizedBox(width: DS.s(20), height: DS.s(20), child: CircularProgressIndicator(strokeWidth: DS.s(2.4), color: fg)),
          Gap.h(10),
        ],
        Flexible(child: FitLine3D(text: label, style: Ink3D.text(white ? 16 : 17, FontWeight.w700, fg))),
      ]),
    );
    return Opacity(
      opacity: on || loading ? 1 : 0.45,
      child: Tap3D(onTap: on ? onTap : null, label: label, exclude: true, child: body),
    );
  }
}

class PlanHistoryPill extends StatelessWidget {
  const PlanHistoryPill({super.key, required this.tone, required this.art, required this.onTap});

  final ListingTone tone;
  final String art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(12), DS.s(18), 0),
        child: Tap3D(
          onTap: onTap,
          label: 'History',
          exclude: true,
          child: Container(
            padding: EdgeInsets.fromLTRB(DS.s(8), DS.s(6), DS.s(16), DS.s(6)),
            decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.circular(22), boxShadow: tone.glow(blur: 8, dy: 4)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Art3D(asset: art, size: 26, shadowBlur: 2, shadowOffset: const Offset(1, 2), shadowAlpha: 0.3),
              Gap.h(6),
              Text('History', style: Ink3D.text(14, FontWeight.w700, Colors.white)),
            ]),
          ),
        ),
      ),
    );
  }
}

class PlanHeroPill {
  const PlanHeroPill(this.label, {this.filled = false});
  final String label;
  final bool filled;
}

class PlanHeroCard3D extends StatelessWidget {
  const PlanHeroCard3D({super.key, required this.tone, required this.art, required this.pills, required this.name, required this.subtitle, this.lines = const [], this.pausedLabel});

  final ListingTone tone;
  final String art;
  final List<PlanHeroPill> pills;
  final String name;
  final String subtitle;
  final List<String> lines;
  final String? pausedLabel;

  static const double topRoom = 52;

  @override
  Widget build(BuildContext context) {
    final narrow = PlanLook.narrowness(context) < Form3D.narrow;
    final artSize = narrow ? 104.0 : 130.0;
    final clear = DS.s(narrow ? 100.0 : 124.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(topRoom), DS.s(18), 0),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          constraints: BoxConstraints(minHeight: DS.s(170)),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(DS.s(22), DS.s(20), DS.s(22), DS.s(20)),
          decoration: BoxDecoration(
            gradient: tone.gradient,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(68)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
            boxShadow: tone.glow(),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: DS.s(24)),
              child: Padding(
                padding: EdgeInsets.only(right: clear),
                child: Wrap(spacing: DS.gh(6), runSpacing: DS.gv(6), children: [
                  for (final p in pills)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: DS.s(11), vertical: DS.s(3)),
                      decoration: BoxDecoration(color: p.filled ? Colors.white : PlanInk.pillFill, borderRadius: DS.circular(12)),
                      child: Text(p.label, style: Ink3D.text(11.5, FontWeight.w700, p.filled ? tone.g2 : Colors.white)),
                    ),
                ]),
              ),
            ),
            Gap.v(6),
            Padding(
              padding: EdgeInsets.only(right: clear),
              child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(24, FontWeight.w700, Colors.white, height: 1.15)),
            ),
            Gap.v(2),
            Padding(
              padding: EdgeInsets.only(right: clear),
              child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Colors.white.withValues(alpha: 0.92), height: 1.35)),
            ),
            if (lines.isNotEmpty) ...[
              Gap.v(12),
              for (final l in lines)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: DS.gv(3)),
                  child: Row(children: [
                    Container(
                      width: DS.s(20),
                      height: DS.s(20),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded, size: DS.s(14), color: tone.g2),
                    ),
                    Gap.h(10),
                    Expanded(child: Text(l, style: Ink3D.text(14, FontWeight.w500, Colors.white))),
                  ]),
                ),
            ],
            if (pausedLabel != null)
              Container(
                margin: EdgeInsets.only(top: DS.gv(10)),
                padding: EdgeInsets.symmetric(horizontal: DS.s(11), vertical: DS.s(3)),
                decoration: BoxDecoration(color: PlanInk.pillFill, borderRadius: DS.circular(12)),
                child: Text(pausedLabel!, style: Ink3D.text(11.5, FontWeight.w700, Colors.white)),
              ),
          ]),
        ),
        Positioned(
          right: DS.s(14),
          top: DS.s(narrow ? -34 : -44),
          child: ExcludeSemantics(child: Art3D(asset: art, size: artSize, halo: artSize + 6, haloColor: Colors.white.withValues(alpha: 0.2), haloDy: 6, shadowAlpha: 0.3)),
        ),
      ]),
    );
  }
}

class PlanSectionTitle extends StatelessWidget {
  const PlanSectionTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.gv(28), DS.s(18), DS.gv(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Ink3D.text(18, FontWeight.w600, Ink3D.body, letterSpacing: 0.4)),
        Gap.v(4),
        Text(subtitle, style: Ink3D.text(13, FontWeight.w400, PlanInk.muted, letterSpacing: 0)),
      ]),
    );
  }
}

enum PlanCellKind { number, yes, no }

class PlanCellData {
  const PlanCellData(this.text, this.kind);
  final String text;
  final PlanCellKind kind;
}

class PlanRowData {
  const PlanRowData({required this.label, required this.art, required this.cells});
  final String label;
  final String art;
  final List<PlanCellData> cells;
}

class PlanCompareCard3D extends StatelessWidget {
  const PlanCompareCard3D({super.key, required this.tone, required this.paidNames, required this.rows, this.showBest = true});

  final ListingTone tone;
  final List<String> paidNames;
  final List<PlanRowData> rows;
  final bool showBest;

  List<int> get _flex => paidNames.length > 1 ? const [15, 6, 9, 9] : const [21, 7, 10];

  Widget _row(List<Widget> cells, {required double minHeight, Color? color, bool top = true}) {
    final f = _flex;
    return Container(
      constraints: BoxConstraints(minHeight: DS.s(minHeight)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(14), vertical: DS.s(6)),
      decoration: BoxDecoration(color: color, border: top ? const Border(top: BorderSide(color: PlanInk.line)) : null),
      child: Row(children: [
        for (var i = 0; i < cells.length; i++) Expanded(flex: f[math.min(i, f.length - 1)], child: cells[i]),
      ]),
    );
  }

  Widget _cell(PlanCellData c, bool paid) => Center(
        child: switch (c.kind) {
          PlanCellKind.yes => Container(
              width: DS.s(24),
              height: DS.s(24),
              decoration: const BoxDecoration(gradient: PlanInk.check, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, size: DS.s(15), color: Colors.white),
            ),
          PlanCellKind.no => Text('−', style: Ink3D.text(15, FontWeight.w700, PlanInk.number)),
          PlanCellKind.number => FitLine3D(text: c.text, style: Ink3D.text(15, FontWeight.w700, paid ? tone.g2 : PlanInk.number)),
        },
      );

  @override
  Widget build(BuildContext context) {
    final head = _row([
      const SizedBox(),
      Center(child: FitLine3D(text: 'Free', style: Ink3D.text(13, FontWeight.w600, PlanInk.muted))),
      for (var k = 0; k < paidNames.length; k++)
        Column(mainAxisSize: MainAxisSize.min, children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(paidNames[k], maxLines: 1, softWrap: false, textAlign: TextAlign.center, style: Ink3D.text(13, FontWeight.w700, tone.g2, height: 1.2))),
          if (showBest && k == paidNames.length - 1)
            Container(
              margin: EdgeInsets.only(top: DS.gv(2)),
              padding: EdgeInsets.symmetric(horizontal: DS.s(8), vertical: DS.s(1)),
              decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.circular(9)),
              child: Text('BEST', style: Ink3D.text(10, FontWeight.w700, Colors.white, letterSpacing: 0.6)),
            ),
        ]),
    ], minHeight: 58, color: PlanInk.headRow, top: false);
    return Container(
      margin: EdgeInsets.symmetric(horizontal: DS.s(18)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(24)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
        boxShadow: PlanInk.cardSoft,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        head,
        for (final r in rows)
          _row([
            Row(children: [
              Art3D(asset: r.art, size: 34, shadowBlur: 2, shadowOffset: const Offset(2, 3), shadowAlpha: 0.22),
              Gap.h(10),
              Expanded(child: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w500, Ink3D.title, height: 1.25))),
            ]),
            for (var i = 0; i < r.cells.length; i++) _cell(r.cells[i], i > 0),
          ], minHeight: 56),
      ]),
    );
  }
}

class PlanChoiceChip3D extends StatelessWidget {
  const PlanChoiceChip3D({super.key, required this.tone, required this.label, required this.selected, required this.onTap});

  final ListingTone tone;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(24), DS.s(18), 0),
        child: Tap3D(
          onTap: onTap,
          label: label,
          selected: selected,
          exclude: true,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: DS.s(18), vertical: DS.s(8)),
            decoration: BoxDecoration(
              color: selected ? null : tone.halo,
              gradient: selected ? tone.gradient : null,
              borderRadius: DS.circular(22),
              boxShadow: selected ? tone.glow(blur: 8) : null,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, selected ? Colors.white : tone.text)),
          ),
        ),
      ),
    );
  }
}

class PlanCycleCard3D extends StatelessWidget {
  const PlanCycleCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.perMonth,
    required this.best,
    required this.selected,
    required this.onTap,
    this.unavailableText,
    this.onRetry,
    this.subtitleLoading = false,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String subtitle;
  final String? price;
  final String? perMonth;
  final bool best;
  final bool selected;
  final VoidCallback onTap;
  final String? unavailableText;
  final VoidCallback? onRetry;
  final bool subtitleLoading;

  static const double topRoom = 42;

  Widget _bone(double w, double h, double r) => Container(
        width: DS.s(w),
        height: DS.s(h),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4), borderRadius: DS.circular(r)),
      );

  @override
  Widget build(BuildContext context) {
    final width = PlanLook.narrowness(context);
    final narrow = width < Form3D.narrow;
    final compact = width < 380;
    final artSize = narrow ? 64.0 : (compact ? 76.0 : 88.0);
    final left = DS.s(narrow ? 76.0 : (compact ? 90.0 : 104.0));
    final k = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final stackAlways = narrow || MediaQuery.textScalerOf(context).scale(10) > 11.5;
    final white = Colors.white;
    final soft = Colors.white.withValues(alpha: 0.94);
    final ua = unavailableText;
    final p = price;

    final Widget priceSlot;
    final Widget perSlot;
    if (ua != null) {
      priceSlot = Text(ua, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: Ink3D.text(12, FontWeight.w700, white, height: 1.15));
      perSlot = onRetry == null
          ? SizedBox(height: DS.s(18))
          : Tap3D(
              onTap: onRetry,
              label: 'Retry',
              exclude: true,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: DS.s(12), vertical: DS.s(1)),
                decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(9)),
                child: Text('Retry', style: Ink3D.text(11, FontWeight.w700, PlanInk.good)),
              ),
            );
    } else if (p == null) {
      priceSlot = _bone(58, 20, 6);
      perSlot = _bone(56, 8, 4);
    } else {
      priceSlot = FitLine3D(text: p, style: Ink3D.text(22, FontWeight.w700, white, height: 1.1));
      final pm = perMonth;
      perSlot = pm == null || pm.isEmpty ? SizedBox(height: DS.s(18)) : FitLine3D(text: pm, style: Ink3D.text(11, FontWeight.w500, soft));
    }

    final card = Container(
      constraints: BoxConstraints(minHeight: DS.s(128)),
      padding: EdgeInsets.fromLTRB(left, DS.s(12), DS.s(14), DS.s(12)),
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(40)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
        border: Border.all(color: selected ? Colors.white : Colors.transparent, width: DS.s(3)),
        boxShadow: selected ? tone.glow(blur: 14, dy: 6) : null,
      ),
      child: Row(children: [
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final scaler = MediaQuery.textScalerOf(context);
            final titleStyle = Ink3D.text(17, FontWeight.w700, white);
            final uaStyle = Ink3D.text(12, FontWeight.w700, white, height: 1.15);
            final titleW = _textWidth(title, titleStyle, scaler);
            final room = box.maxWidth - titleW - DS.gh(8);
            final noteBelow = ua != null && onRetry == null && !stackAlways && _textWidth(ua, uaStyle, scaler) > room;
            final inRow = !stackAlways &&
                (noteBelow ||
                    (ua != null
                        ? _wrapsInTwo(ua, uaStyle, scaler, room)
                        : (p != null ? _textWidth(p, Ink3D.text(22, FontWeight.w700, white), scaler) : DS.s(58.0)) <= room));
            final Widget titleBlock;
            if (inRow) {
              titleBlock = SizedBox(
                height: DS.s(30) * k,
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: noteBelow
                    ? [Expanded(child: FitLine3D(text: title, style: titleStyle))]
                    : ua != null
                        ? [
                            SizedBox(width: titleW.ceilToDouble() + 1, child: FitLine3D(text: title, style: titleStyle)),
                            Gap.h(8),
                            Expanded(child: Align(alignment: Alignment.centerRight, child: priceSlot)),
                          ]
                        : [
                            Expanded(child: FitLine3D(text: title, style: titleStyle)),
                            Gap.h(8),
                            ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6), child: priceSlot),
                          ]),
              );
            } else {
              titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                SizedBox(height: DS.s(26) * k, child: Align(alignment: Alignment.centerLeft, child: FitLine3D(text: title, style: titleStyle))),
                Gap.v(4),
                SizedBox(height: DS.s(30) * k, child: Align(alignment: Alignment.centerRight, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth), child: priceSlot))),
              ]);
            }
            final per = noteBelow ? Text(ua, maxLines: 1, overflow: TextOverflow.ellipsis, style: uaStyle) : perSlot;
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: DS.s(20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: best
                      ? Container(
                          padding: EdgeInsets.symmetric(horizontal: DS.s(8), vertical: DS.s(2)),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(9)),
                          child: Text('BEST VALUE', style: Ink3D.text(10, FontWeight.w700, PlanInk.good, letterSpacing: 0.6)),
                        )
                      : null,
                ),
              ),
              Gap.v(6),
              titleBlock,
              Gap.v(6),
              SizedBox(height: DS.s(20) * k, child: Align(alignment: Alignment.centerRight, child: per)),
              Gap.v(4),
              SizedBox(
                height: DS.s(18) * k,
                child: subtitleLoading
                    ? Align(alignment: Alignment.centerLeft, child: _bone(110, 8, 4))
                    : Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(subtitle, maxLines: 1, softWrap: false, style: Ink3D.text(11.5, FontWeight.w500, soft, height: 1.3)))),
              ),
            ]);
          }),
        ),
        Gap.h(10),
        Container(
          width: DS.s(26),
          height: DS.s(26),
          decoration: BoxDecoration(color: selected ? Colors.white : Colors.white.withValues(alpha: 0.35), shape: BoxShape.circle),
          child: selected ? Icon(Icons.check_rounded, size: DS.s(16), color: tone.g2) : null,
        ),
      ]),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(topRoom), DS.s(18), 0),
      child: Tap3D(
        onTap: onTap,
        label: '$title${p == null ? '' : ', $p'}',
        selected: selected,
        child: Stack(clipBehavior: Clip.none, children: [
          Opacity(opacity: selected ? 1 : 0.8, child: card),
          Positioned(
            left: DS.s(8),
            top: DS.s(narrow ? -22 : (compact ? -26 : -32)),
            child: ExcludeSemantics(child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: Colors.white.withValues(alpha: 0.22), shadowBlur: 5, shadowOffset: const Offset(4, 6))),
          ),
        ]),
      ),
    );
  }
}

bool _wrapsInTwo(String text, TextStyle style, TextScaler scaler, double width) {
  if (width <= 0) return false;
  final widest = text.split(' ').fold<double>(0, (m, w) => math.max(m, _textWidth(w, style, scaler)));
  if (widest > width) return false;
  final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 2)..layout(maxWidth: width);
  final ok = !tp.didExceedMaxLines;
  tp.dispose();
  return ok;
}

double _textWidth(String text, TextStyle style, TextScaler scaler) {
  final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
  final w = tp.width;
  tp.dispose();
  return w;
}

class PlanLinkText extends StatelessWidget {
  const PlanLinkText({super.key, required this.tone, required this.label, required this.onTap, this.secondary = false});

  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: secondary ? DS.gv(16) : DS.gv(20)),
      child: Center(
        child: Tap3D(
          onTap: onTap,
          label: label,
          exclude: true,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: DS.s(12), vertical: DS.s(4)),
            child: Text(label,
                style: secondary
                    ? Ink3D.text(14, FontWeight.w600, PlanInk.muted, letterSpacing: 0)
                    : Ink3D.text(15, FontWeight.w700, tone.text, letterSpacing: 0)),
          ),
        ),
      ),
    );
  }
}

class PlanCouponRow3D extends StatelessWidget {
  const PlanCouponRow3D({super.key, required this.tone, required this.art, required this.field, required this.applied, required this.onTap});

  final ListingTone tone;
  final String art;
  final Widget field;
  final bool applied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(20), DS.s(18), 0),
      child: Row(children: [
        Expanded(
          child: Container(
            constraints: BoxConstraints(minHeight: DS.s(54)),
            padding: EdgeInsets.fromLTRB(DS.s(10), 0, DS.s(16), 0),
            decoration: BoxDecoration(
              color: applied ? PlanInk.headRow : Colors.white,
              borderRadius: DS.circular(38),
              boxShadow: applied ? null : PlanInk.whiteButton,
            ),
            child: Row(children: [
              Art3D(asset: art, size: 38, shadowBlur: 3, shadowOffset: const Offset(2, 4)),
              Gap.h(10),
              Expanded(child: field),
            ]),
          ),
        ),
        Gap.h(10),
        Tap3D(
          onTap: onTap,
          label: applied ? 'Remove' : 'Apply',
          exclude: true,
          child: Container(
            width: DS.s(104),
            height: DS.s(54),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: applied ? Colors.white : null,
              gradient: applied ? null : tone.gradient,
              borderRadius: DS.circular(27),
              boxShadow: applied ? PlanInk.whiteButton : DS.shadows(Form3D.glow(tone, offset: const Offset(3, 6), blur: 12)),
            ),
            child: FitLine3D(text: applied ? 'Remove' : 'Apply', style: Ink3D.text(15, FontWeight.w700, applied ? tone.text : Colors.white)),
          ),
        ),
      ]),
    );
  }

  static TextStyle fieldStyle(bool applied) => Ink3D.text(15, FontWeight.w400, applied ? PlanInk.label : Ink3D.title, letterSpacing: 0.5);
  static TextStyle hintStyle() => Ink3D.text(15, FontWeight.w400, Form3D.hint, letterSpacing: 0);
}

enum PlanNoteKind { plain, good, bad, warn }

class PlanBar3D extends StatelessWidget {
  const PlanBar3D({
    super.key,
    required this.tone,
    required this.left,
    required this.right,
    required this.ctaLabel,
    required this.onCta,
    this.note,
    this.noteKind = PlanNoteKind.plain,
    this.ctaLoading = false,
    this.trialLabel,
    this.onTrial,
    this.trialNote,
  });

  final ListingTone tone;
  final String left;
  final Widget right;
  final String? note;
  final PlanNoteKind noteKind;
  final String ctaLabel;
  final VoidCallback? onCta;
  final bool ctaLoading;
  final String? trialLabel;
  final VoidCallback? onTrial;
  final String? trialNote;

  static Widget price(String text, {bool good = false, bool muted = false}) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: muted
            ? Ink3D.text(13, FontWeight.w500, PlanInk.muted)
            : Ink3D.text(16, FontWeight.w700, good ? PlanInk.good : Ink3D.title),
      );

  static Widget get placeholder => SkeletonBox(width: DS.s(84), height: DS.s(18), radius: DS.radius(6));

  static String _glue(String t) => t.replaceAll('− ₹', '− ₹').replaceAll(RegExp(r'(?<=[A-Za-z0-9]) −'), ' −');

  Color get _noteColor => switch (noteKind) {
        PlanNoteKind.plain => PlanInk.muted,
        PlanNoteKind.good => PlanInk.good,
        PlanNoteKind.bad => PlanInk.bad,
        PlanNoteKind.warn => PlanInk.warn,
      };

  @override
  Widget build(BuildContext context) {
    final n = note;
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s(20), DS.s(14), DS.s(20), DS.s(22) + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(28))),
        boxShadow: PlanInk.barShadow,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: DS.s(52)),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(left, maxLines: 1, softWrap: false, style: Ink3D.text(13, FontWeight.w600, PlanInk.label, height: 1.5, letterSpacing: 0))),
                if (n != null)
                  Padding(
                    padding: EdgeInsets.only(top: DS.gv(2)),
                    child: LayoutBuilder(builder: (context, box) {
                      final text = _glue(n);
                      final style = Ink3D.text(12, FontWeight.w600, _noteColor, height: 1.33, letterSpacing: 0);
                      final w = _textWidth(text, style, MediaQuery.textScalerOf(context));
                      if (w > box.maxWidth && w <= box.maxWidth / 0.85) {
                        return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(text, maxLines: 1, softWrap: false, style: style));
                      }
                      return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: style);
                    }),
                  ),
              ]),
            ),
            Gap.h(12),
            Flexible(child: Align(alignment: Alignment.centerRight, child: right)),
          ]),
        ),
        Gap.v(12),
        PlanBarButton(tone: tone, label: ctaLabel, onTap: onCta, loading: ctaLoading),
        if (trialLabel != null) ...[
          Gap.v(10),
          PlanBarButton(tone: tone, label: trialLabel!, onTap: onTrial, white: true),
          if (trialNote != null)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(8)),
              child: Text(trialNote!, textAlign: TextAlign.center, style: Ink3D.text(11.5, FontWeight.w400, PlanInk.muted, letterSpacing: 0)),
            ),
        ],
      ]),
    );
  }
}

class PlanSubAction {
  const PlanSubAction(this.label, this.onTap);
  final String label;
  final VoidCallback? onTap;
}

class PlanSubscriptionCard3D extends StatelessWidget {
  const PlanSubscriptionCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.eyebrow,
    required this.title,
    required this.manage,
    required this.footer,
    required this.footerArt,
    this.pills = const [],
    this.testPill,
    this.body,
    this.notes = const [],
    this.action,
  });

  final ListingTone tone;
  final String art;
  final String eyebrow;
  final List<String> pills;
  final String? testPill;
  final String title;
  final String? body;
  final List<(String, String)> notes;
  final PlanSubAction? action;
  final PlanSubAction manage;
  final String footer;
  final String footerArt;

  static const double topRoom = 60;

  Widget _pill(String label, Color fill) => Container(
        padding: EdgeInsets.symmetric(horizontal: DS.s(9), vertical: DS.s(1)),
        decoration: BoxDecoration(color: fill, borderRadius: DS.circular(10)),
        child: Text(label, style: Ink3D.text(11, FontWeight.w700, Colors.white)),
      );

  Widget _button(PlanSubAction a, {required bool primary, double size = 12}) => Tap3D(
        onTap: a.onTap,
        label: a.label,
        exclude: true,
        child: Container(
          constraints: BoxConstraints(minHeight: DS.s(44)),
          padding: EdgeInsets.symmetric(horizontal: DS.s(6), vertical: DS.s(6)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? Colors.white : PlanInk.onCardFill,
            borderRadius: DS.circular(22),
            border: primary ? null : Border.all(color: PlanInk.onCardRing, width: 1.5),
            boxShadow: primary ? PlanInk.onCardButton : null,
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(a.label, maxLines: 1, softWrap: false, textAlign: TextAlign.center, style: Ink3D.text(size, FontWeight.w700, primary ? tone.g2 : Colors.white, height: 1.25))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final narrow = PlanLook.narrowness(context) < Form3D.narrow;
    final artSize = narrow ? 92.0 : 116.0;
    final left = DS.s(narrow ? 104.0 : 130.0);
    final a = action;
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(topRoom), DS.s(18), 0),
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: tone.gradient,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(54)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
            boxShadow: tone.glow(),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: DS.s(112)),
              child: Padding(
                padding: EdgeInsets.fromLTRB(left, DS.s(12), DS.s(18), DS.s(8)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: DS.s(20)),
                    child: Wrap(spacing: DS.gh(6), runSpacing: DS.gv(4), crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(eyebrow, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, Colors.white.withValues(alpha: 0.95))),
                      for (final p in pills) _pill(p, PlanInk.onCardFill),
                      if (testPill != null) _pill(testPill!, PlanInk.testPill),
                    ]),
                  ),
                  Gap.v(2),
                  Text(title, style: Ink3D.text(17, FontWeight.w700, Colors.white, height: 1.3)),
                  if (body != null && body!.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: DS.gv(2)),
                      child: Text(body!, style: Ink3D.text(12.5, FontWeight.w500, Colors.white.withValues(alpha: 0.96), height: 1.44)),
                    ),
                  for (final n in notes)
                    Padding(
                      padding: EdgeInsets.only(top: DS.gv(2)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(padding: EdgeInsets.only(top: DS.gv(1)), child: Art3D(asset: n.$1, size: 18, shadowBlur: 2, shadowOffset: const Offset(1, 2), shadowAlpha: 0.3)),
                        Gap.h(6),
                        Expanded(child: Text(n.$2, style: Ink3D.text(12.5, FontWeight.w500, Colors.white.withValues(alpha: 0.96), height: 1.44))),
                      ]),
                    ),
                ]),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(4), DS.s(14), 0),
              child: a == null
                  ? _button(manage, primary: false)
                  : IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: _button(a, primary: true, size: 11.5)),
                      Gap.h(8),
                      Expanded(child: _button(manage, primary: false, size: 11.5)),
                    ]),
                    ),
            ),
            Container(
              margin: EdgeInsets.only(top: DS.gv(14)),
              padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(9), DS.s(18), DS.s(9)),
              decoration: BoxDecoration(color: PlanInk.footStrip, borderRadius: BorderRadius.vertical(bottom: Radius.circular(DS.radius(8)))),
              child: Row(children: [
                Art3D(asset: footerArt, size: 22, shadowBlur: 2, shadowOffset: const Offset(1, 2), shadowAlpha: 0.3),
                Gap.h(8),
                Expanded(child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(footer, maxLines: 1, softWrap: false, style: Ink3D.text(12, FontWeight.w500, Colors.white, letterSpacing: 0))))),
              ]),
            ),
          ]),
        ),
        Positioned(
          left: DS.s(6),
          top: DS.s(narrow ? -36 : -48),
          child: ExcludeSemantics(child: Art3D(asset: art, size: artSize, halo: artSize + 4, haloColor: Colors.white.withValues(alpha: 0.22), shadowBlur: 6, shadowOffset: const Offset(5, 8), shadowAlpha: 0.28)),
        ),
      ]),
    );
  }
}

class PlanStateCard3D extends StatelessWidget {
  const PlanStateCard3D({super.key, required this.tone, required this.art, required this.title, this.message, this.actionLabel, this.onAction});

  final ListingTone tone;
  final String art;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final narrow = PlanLook.narrowness(context) < Form3D.narrow;
    final artSize = narrow ? 136.0 : 166.0;
    final m = message;
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(66), DS.s(18), 0),
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(DS.s(24), (m == null || m.isEmpty) ? DS.s(artSize - 34) : DS.s(artSize - 26), DS.s(24), DS.s(26)),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(54)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
            boxShadow: [BoxShadow(color: Color(0x4D9E9E9E), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(12))],
          ),
          child: Column(children: [
            Text(title, textAlign: TextAlign.center, style: Ink3D.text(22, FontWeight.w700, Ink3D.title, height: 1.25)),
            if (m != null && m.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: DS.gv(6)),
                child: Text(m, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w400, PlanInk.copy, height: 1.4, letterSpacing: 0)),
              ),
            if (actionLabel != null && onAction != null)
              Padding(
                padding: EdgeInsets.only(top: DS.gv(22)),
                child: PlanBarButton(tone: tone, label: actionLabel!, onTap: onAction, width: 200),
              ),
          ]),
        ),
        Positioned(
          top: DS.s(narrow ? -38 : -48),
          child: ExcludeSemantics(child: Art3D(asset: art, size: artSize, halo: artSize + 6, haloColor: tone.halo, shadowBlur: 8, shadowOffset: const Offset(6, 10))),
        ),
      ]),
    );
  }
}

class PlanSkeleton3D extends StatelessWidget {
  const PlanSkeleton3D({super.key, this.hero = true, this.rows = 3});

  final bool hero;
  final int rows;

  Widget _block({required double height, required BorderRadius radius, required EdgeInsets margin, required Widget bone, List<Widget> lines = const []}) {
    return Padding(
      padding: margin,
      child: Stack(clipBehavior: Clip.none, children: [
        ClipRRect(borderRadius: radius, child: SkeletonBox(height: DS.s(height), radius: 0)),
        bone,
        ...lines,
      ]),
    );
  }

  Widget _disc(double size) => Container(width: DS.s(size), height: DS.s(size), decoration: const BoxDecoration(color: Color(0xFFD6DAE4), shape: BoxShape.circle));

  Widget _line(double top, double width) => Positioned(
        left: DS.s(128),
        top: DS.s(top),
        child: Container(width: DS.s(width), height: DS.s(14), decoration: BoxDecoration(color: const Color(0xFFD6DAE4), borderRadius: DS.circular(7))),
      );

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (hero)
          _block(
            height: 150,
            radius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(68)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
            margin: EdgeInsets.fromLTRB(DS.s(18), DS.s(52), DS.s(18), 0),
            bone: Positioned(right: DS.s(18), top: DS.s(-36), child: _disc(110)),
          ),
        for (var i = 0; i < rows; i++)
          _block(
            height: 104,
            radius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(54)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
            margin: EdgeInsets.fromLTRB(DS.s(18), DS.s(46), DS.s(18), 0),
            bone: Positioned(left: DS.s(12), top: DS.s(-28), child: _disc(96)),
            lines: [_line(30, 150), _line(58, 100)],
          ),
      ]),
    );
  }
}

class PlanStatusSheet3D extends StatelessWidget {
  const PlanStatusSheet3D({
    super.key,
    required this.tone,
    required this.art,
    required this.status,
    required this.title,
    required this.body,
    required this.waiting,
    this.ring,
    this.onDone,
  });

  final ListingTone tone;
  final String art;
  final Color status;
  final String title;
  final String body;
  final bool waiting;
  final Animation<double>? ring;
  final VoidCallback? onDone;

  static const double artRoom = 86;
  static const double height = 276;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final Widget foot = waiting
        ? SizedBox(
            height: DS.s(54),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final a in const [0.35, 0.65, 1.0])
                Container(
                  margin: EdgeInsets.symmetric(horizontal: DS.s(4)),
                  width: DS.s(9),
                  height: DS.s(9),
                  decoration: BoxDecoration(color: status.withValues(alpha: a), shape: BoxShape.circle),
                ),
            ]),
          )
        : PlanBarButton(tone: tone, label: 'Done', onTap: onDone);
    final r = ring;
    return Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
      Padding(
        padding: EdgeInsets.only(top: DS.s(artRoom)),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: DS.s(height) + bottom),
          padding: EdgeInsets.fromLTRB(DS.s(24), DS.s(84), DS.s(24), DS.s(22) + bottom),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(32))),
            boxShadow: PlanInk.sheetShadow,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, textAlign: TextAlign.center, style: Ink3D.text(24, FontWeight.w700, Ink3D.title, height: 1.25)),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: DS.s(50)),
              child: Padding(
                padding: EdgeInsets.only(top: DS.gv(6)),
                child: Text(body, textAlign: TextAlign.center, style: Ink3D.text(15, FontWeight.w400, PlanInk.copy, height: 1.45, letterSpacing: 0)),
              ),
            ),
            Gap.v(22),
            foot,
          ]),
        ),
      ),
      if (waiting)
        Positioned(
          top: 0,
          child: SizedBox(
            width: DS.s(160),
            height: DS.s(160),
            child: r == null
                ? _Ring(color: status, turn: 0)
                : AnimatedBuilder(animation: r, builder: (_, _) => _Ring(color: status, turn: r.value)),
          ),
        ),
      Positioned(
        top: DS.s(12),
        child: ExcludeSemantics(child: Art3D(asset: art, size: 136, halo: 144, haloColor: status.withValues(alpha: 0.18), shadowBlur: 7, shadowOffset: const Offset(5, 9), shadowAlpha: 0.3)),
      ),
    ]);
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.color, required this.turn});

  final Color color;
  final double turn;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _RingPainter(color, turn));
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.color, this.turn);

  final Color color;
  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(DS.s(2.5));
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = DS.s(5)
      ..color = color.withValues(alpha: 0.2);
    canvas.drawOval(rect, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = DS.s(5)
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -math.pi * 3 / 4 + turn * 2 * math.pi, math.pi, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.turn != turn || old.color != color;
}

class PlanCloseSheet3D extends StatelessWidget {
  const PlanCloseSheet3D({super.key, required this.tone, required this.onClose});

  final ListingTone tone;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(DS.s(22), DS.s(22), DS.s(22), DS.s(26) + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(32))), boxShadow: PlanInk.sheetShadow),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Tap3D(
          onTap: onClose,
          label: 'Close',
          exclude: true,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: DS.s(50)),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(18), boxShadow: PlanInk.whiteButton),
            child: Text('Close', style: Ink3D.text(16, FontWeight.w700, tone.text)),
          ),
        ),
      ]),
    );
  }
}

class PlanHistoryCard3D extends StatelessWidget {
  const PlanHistoryCard3D({super.key, required this.tone, required this.art, required this.title, required this.date, required this.amount, required this.status, required this.statusColor});

  final ListingTone tone;
  final String art;
  final String title;
  final String date;
  final String amount;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final narrow = PlanLook.narrowness(context) < Form3D.narrow;
    final artSize = narrow ? 72.0 : 100.0;
    final left = DS.s(narrow ? 84.0 : 132.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(46), DS.s(14), DS.s(8)),
      child: Semantics(
        container: true,
        label: '$title, $date, $amount, $status',
        excludeSemantics: true,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(minHeight: DS.s(112)),
            padding: EdgeInsets.fromLTRB(left, DS.s(16), narrow ? DS.s(14) : DS.s(20), DS.s(16)),
            decoration: BoxDecoration(
              gradient: tone.gradient,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(54)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
              boxShadow: [BoxShadow(color: tone.shadow, offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(10))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Colors.white, height: 1.2)),
              Gap.v(2),
              Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, Colors.white.withValues(alpha: 0.96))),
              Gap.v(8),
              LayoutBuilder(builder: (context, box) {
                final scaler = MediaQuery.textScalerOf(context);
                final amountStyle = Ink3D.text(24, FontWeight.w600, Colors.white, height: 1);
                final statusStyle = Ink3D.text(12, FontWeight.w700, statusColor);
                final padX = DS.s(narrow ? 10.0 : 12.0);
                final pill = Container(
                  padding: EdgeInsets.symmetric(horizontal: padX, vertical: DS.s(4)),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(12), boxShadow: PlanInk.pillShadow),
                  child: Text(status, maxLines: 1, style: statusStyle),
                );
                final need = _textWidth(amount, amountStyle, scaler) + DS.gh(8) + _textWidth(status, statusStyle, scaler) + padX * 2;
                if (need <= box.maxWidth) {
                  return Row(children: [
                    Expanded(child: FitLine3D(text: amount, style: amountStyle)),
                    Gap.h(8),
                    pill,
                  ]);
                }
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  FitLine3D(text: amount, style: amountStyle),
                  Gap.v(8),
                  Align(alignment: Alignment.centerRight, child: pill),
                ]);
              }),
            ]),
          ),
          Positioned(
            left: DS.s(12),
            top: DS.s(narrow ? -18 : -24),
            child: Art3D(asset: art, size: artSize, halo: artSize + 8, haloColor: Colors.white.withValues(alpha: 0.24)),
          ),
        ]),
      ),
    );
  }
}

class LegalCard3D extends StatelessWidget {
  const LegalCard3D({super.key, required this.children, this.continued = false});

  final List<Widget> children;
  final bool continued;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(DS.s(18), DS.gv(6), DS.s(18), 0),
      padding: EdgeInsets.fromLTRB(DS.s(20), DS.s(20), DS.s(20), DS.s(24)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: continued
            ? DS.circular(8)
            : BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(54)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
        boxShadow: [BoxShadow(color: Color(0x339E9E9E), offset: DS.shadowOffset(const Offset(1.1, 1.1)), blurRadius: DS.shadowBlur(10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class LegalIntro3D extends StatelessWidget {
  const LegalIntro3D(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(right: DS.s(24)),
        child: Text(text, style: Ink3D.text(14, FontWeight.w400, PlanInk.label, height: 1.6, letterSpacing: 0)),
      );
}

class LegalSection3D extends StatelessWidget {
  const LegalSection3D({super.key, required this.tone, required this.art, required this.title, this.body, this.bullets = const [], this.first = false});

  final ListingTone tone;
  final String art;
  final String title;
  final String? body;
  final List<String> bullets;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final style = Ink3D.text(13.5, FontWeight.w400, PlanInk.label, height: 1.6, letterSpacing: 0);
    return Container(
      margin: EdgeInsets.only(top: first ? 0 : DS.gv(16)),
      padding: EdgeInsets.only(top: first ? DS.s(4) : DS.s(18), bottom: DS.s(6)),
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: PlanInk.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SizedBox(
            width: DS.s(44),
            height: DS.s(44),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(width: DS.s(44), height: DS.s(44), decoration: BoxDecoration(color: tone.haloBase.withValues(alpha: 0.14), borderRadius: DS.circular(14))),
              Positioned(left: DS.s(-4), top: DS.s(-9), child: ExcludeSemantics(child: Art3D(asset: art, size: 54, shadowBlur: 3, shadowOffset: const Offset(2, 4)))),
            ]),
          ),
          Gap.h(12),
          Expanded(child: Semantics(header: true, child: Text(title, style: Ink3D.text(16, FontWeight.w700, Ink3D.title, height: 1.25)))),
        ]),
        if (body != null && body!.isNotEmpty) Padding(padding: EdgeInsets.only(top: DS.gv(10)), child: Text(body!, style: style)),
        if (bullets.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: DS.gv(6)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final b in bullets)
                Padding(
                  padding: EdgeInsets.only(top: DS.gv(7)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      margin: EdgeInsets.fromLTRB(DS.s(2), DS.gv(8), DS.s(9), 0),
                      width: DS.s(9),
                      height: DS.s(9),
                      decoration: BoxDecoration(gradient: tone.gradient, shape: BoxShape.circle),
                    ),
                    Expanded(child: Text(b, style: style.copyWith(height: 1.55))),
                  ]),
                ),
            ]),
          ),
      ]),
    );
  }
}

class LegalCaption3D extends StatelessWidget {
  const LegalCaption3D(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: DS.gv(26)),
        child: Text(text, textAlign: TextAlign.center, style: Ink3D.text(12.5, FontWeight.w400, PlanInk.number, letterSpacing: 0)),
      );
}

class LegalCompactBar3D extends StatelessWidget {
  const LegalCompactBar3D({super.key, required this.tone, required this.title, required this.onBack});

  final ListingTone tone;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tip = MaterialLocalizations.of(context).backButtonTooltip;
    return Container(
      padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(8), DS.s(18), DS.s(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(DS.radius(24))),
        boxShadow: [BoxShadow(color: Color(0x409E9E9E), offset: DS.shadowOffset(const Offset(0, 4)), blurRadius: DS.shadowBlur(14))],
      ),
      child: Row(children: [
        Tooltip(
          message: tip,
          excludeFromSemantics: true,
          child: Tap3D(
            onTap: onBack,
            label: tip,
            exclude: true,
            child: Container(
              width: DS.s(42),
              height: DS.s(42),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: DS.shadows(Ink3D.softShadow)),
              child: Icon(Icons.chevron_left_rounded, size: DS.s(26), color: tone.text),
            ),
          ),
        ),
        Gap.h(12),
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(19, FontWeight.w700, Ink3D.title))),
      ]),
    );
  }
}
