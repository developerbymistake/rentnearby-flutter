import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:get/get.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../trip_strings_dayplan.dart';
import '../trip_strings_mca_a3.dart';
import '../trip_strings_mca_n2.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../utils/trip_format.dart';
import 'trip_leg_actions.dart';

class TripLegHeader extends StatelessWidget {
  const TripLegHeader({super.key, required this.legIndex, this.anchorKey, this.folded = false, this.onToggle, this.onCustomize, this.body = const [], this.gapBelow = 0});

  final List<Widget> body;

  final int legIndex;
  final GlobalKey? anchorKey;
  final bool folded;
  final VoidCallback? onToggle;
  final VoidCallback? onCustomize;
  final double gapBelow;

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final p = c.plan.value;
      c.trip.value;
      final leg = p?.legAt(legIndex);
      if (p == null || leg == null) return SizedBox.shrink(key: anchorKey);
      final a = p.legStart(legIndex);
      final b = p.legEnd(legIndex);
      final spots = p.legSpotCount(legIndex);
      final from = c.dateOf(a);
      final to = c.dateOf(b);
      final range = TripStringsDayplan.legRange(a, b, from == null || to == null ? null : TripFormat.compactRange(from, to));
      final nights = TripStringsMcaA3.nights(p.legDayCount(legIndex));
      final canRemove = !c.isReadOnly && !c.needsUpdate.value && c.canRemoveLeg(legIndex) != TripLegEditBlock.onlyLeg;
      final unavailable = c.legUnavailable(legIndex);
      return Column(
        key: anchorKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TripLegSectionHeader(
            title: leg.cityName,
            rangeLine: range,
            detailLine: spots > 0 ? '${TripStringsMcaA3.spots(spots)} · $nights' : nights,
            foldedLine: TripStringsDayplan.foldedSummary(p.legDayCount(legIndex), spots),
            folded: folded,
            locked: !c.canEditStructure,
            onToggle: onToggle,
            onCustomize: onCustomize,
            body: body,
            gapBelow: unavailable ? 0 : gapBelow,
          ),
          if (unavailable)
            Banner3D(
              kind: BannerKind.bad,
              art: ListingArt.mountain,
              title: TripStringsMcaN2.cityUnavailable,
              actionLabel: canRemove ? TripStringsMcaA3.removeCity : null,
              onAction: canRemove ? () => TripLegActions.removeCity(context, legIndex) : null,
              margin: DS.gapInsets(l: 18, t: 0, r: 18, b: 6),
            ),
        ],
      );
    });
  }
}

class TripLegSectionHeader extends StatelessWidget {
  const TripLegSectionHeader({
    super.key,
    required this.title,
    required this.rangeLine,
    required this.detailLine,
    required this.foldedLine,
    this.folded = false,
    this.locked = false,
    this.onToggle,
    this.onCustomize,
    this.body = const [],
    this.gapBelow = 0,
  });

  final List<Widget> body;
  final double gapBelow;
  final String title;
  final String rangeLine;
  final String detailLine;
  final String foldedLine;
  final bool folded;
  final bool locked;
  final VoidCallback? onToggle;
  final VoidCallback? onCustomize;

  static const Key customizeKey = ValueKey('leg-customize');
  static const Key foldKey = ValueKey('leg-fold');
  static const Key rowKey = ValueKey('leg-row');
  static const Key detailKey = ValueKey('leg-detail');
  static const Key cardKey = ValueKey('leg-card');
  static const Key layersKey = ValueKey('leg-fold-layers');
  static const double dayCardTop = 16;
  static double get gapAbove => DS.gv(20);

  static const BorderRadius openRadius = BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(36));
  static const BorderRadius foldedRadius = BorderRadius.only(
    topLeft: Radius.circular(6),
    topRight: Radius.circular(38),
    bottomLeft: Radius.circular(6),
    bottomRight: Radius.circular(6),
  );
  static const BorderRadius _layerRadius = BorderRadius.only(bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18));

  static const BorderRadius lockRadius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(28),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  static const BorderRadius sectionRadius = BorderRadius.only(
    topLeft: Radius.circular(8),
    topRight: Radius.circular(40),
    bottomLeft: Radius.circular(8),
    bottomRight: Radius.circular(8),
  );

  @override
  Widget build(BuildContext context) {
    final tone = TripLook.cityTone;
    final scaler = MediaQuery.textScalerOf(context);
    const artSize = 68.0;
    final side = DS.s(18);
    final btn = DS.s(40);
    final gap = DS.s(10);
    final pillPad = DS.s(18);
    final ink = TripLook.cityInk;
    final labelStyle = Ink3D.text(13, FontWeight.w700, ink, letterSpacing: 0);
    final foldStyle = Ink3D.text(12.5, FontWeight.w700, ink, letterSpacing: 0);
    final foldLabel = folded ? TripStringsDayplan.show : TripStringsDayplan.hide;
    final customizeW = onCustomize == null ? 0.0 : KitText.widthOf(TripStringsDayplan.customize, labelStyle, scaler) + pillPad * 2;
    final foldRoom = math.max(KitText.widthOf(TripStringsDayplan.show, foldStyle, scaler), KitText.widthOf(TripStringsDayplan.hide, foldStyle, scaler)) + DS.s(14 + 12 + 6 + 18);
    final ctlW = (onCustomize == null ? 0.0 : customizeW + gap) + foldRoom;
    final minText = DS.s(84);
    final lineStyle = Ink3D.text(12.5, FontWeight.w400, DesignColors.tint(Colors.white, Alpha.v93), height: 1.55, letterSpacing: 0);

    final foldBtn = Tap3D(
      tapKey: foldKey,
      onTap: onToggle,
      label: foldLabel,
      child: Container(
        height: btn,
        width: foldRoom,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: BorderRadius.circular(btn / 2), boxShadow: DS.shadows(Ink3D.whiteBtn)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Text(foldLabel, maxLines: 1, style: foldStyle)),
            SizedBox(width: DS.s(6)),
            RotatedBox(
              quarterTurns: folded ? 2 : 0,
              child: CustomPaint(size: Size.square(DS.s(18)), painter: _FoldChevron(ink)),
            ),
          ],
        ),
      ),
    );
    final customizeBtn = onCustomize == null
        ? null
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: locked ? () {} : null,
            child: Tap3D(
              tapKey: customizeKey,
              onTap: locked ? null : onCustomize,
              label: TripStringsDayplan.customize,
              child: Container(
                height: btn,
                padding: EdgeInsets.symmetric(horizontal: pillPad),
                decoration: BoxDecoration(
                  color: locked ? DesignColors.tint(Colors.white, Alpha.v72) : DesignColors.surface,
                  borderRadius: BorderRadius.circular(btn / 2),
                  boxShadow: locked ? null : DS.shadows(Ink3D.whiteBtn),
                ),
                child: Center(
                  widthFactor: 1,
                  child: ExcludeSemantics(
                    child: Text(
                      TripStringsDayplan.customize,
                      maxLines: 1,
                      style: labelStyle,
                    ),
                  ),
                ),
              ),
            ),
          );

    final controls = <Widget>[?customizeBtn, foldBtn];
    final titleText = Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, Colors.white, height: 1.3, letterSpacing: 0));
    final rangeText = Text(rangeLine, maxLines: 2, overflow: TextOverflow.ellipsis, style: lineStyle);
    final detailText = Text(folded ? foldedLine : detailLine, key: detailKey, maxLines: 3, overflow: TextOverflow.ellipsis, style: lineStyle);

    Widget ctl(List<Widget> w) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < w.length; i++) ...[if (i > 0) SizedBox(width: gap), w[i]],
          ],
        );

    Widget row(double room) {
      final beside = room - ctlW - gap >= minText;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (beside)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [titleText, rangeText]),
                ),
                SizedBox(width: gap),
                ctl(controls),
              ],
            )
          else ...[titleText, rangeText],
          detailText,
          if (!beside)
            Padding(
              padding: EdgeInsets.only(top: DS.s(12)),
              child: room >= ctlW
                  ? Row(children: [?customizeBtn, const Spacer(), foldBtn])
                  : Wrap(spacing: gap, runSpacing: DS.s(10), children: [?customizeBtn, foldBtn]),
            ),
        ],
      );
    }

    final card = Container(
      key: cardKey,
      constraints: BoxConstraints(minHeight: DS.s(96)),
      decoration: BoxDecoration(borderRadius: DS.br(folded ? foldedRadius : openRadius), gradient: tone.gradient),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(DS.s(92), DS.s(14), DS.s(14), DS.s(16)),
            child: LayoutBuilder(builder: (_, box) => row(box.maxWidth)),
          ),
          Positioned(
            left: DS.s(10),
            top: DS.s(14),
            child: IgnorePointer(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: DesignColors.tint(Colors.white, Alpha.v22)),
                    child: SizedBox(width: DS.s(66), height: DS.s(66)),
                  ),
                  Positioned(left: -DS.s(2), top: -DS.s(2), child: const Art3D(asset: ListingArt.luggage, size: artSize)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final sectionBody = !folded && body.isNotEmpty
        ? Stack(
            children: [
              Positioned(
                left: DS.s(14),
                top: DS.s(dayCardTop),
                bottom: DS.s(36),
                width: DS.s(4),
                child: DecoratedBox(decoration: BoxDecoration(color: DesignColors.tint(tone.g1, Alpha.v40), borderRadius: DS.circular(2))),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(DS.s(30), 0, DS.s(12), DS.s(24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: body),
              ),
            ],
          )
        : null;
    final section = DecoratedBox(
      decoration: BoxDecoration(
        color: tone.tint,
        border: Border.all(color: DesignColors.tint(tone.haloBase, Alpha.v25), width: DS.s(2)),
        borderRadius: DS.br(sectionRadius),
        boxShadow: tone.glow(blur: 14),
      ),
      child: Padding(
        padding: EdgeInsets.all(DS.s(2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(key: rowKey, behavior: HitTestBehavior.opaque, onTap: onToggle, child: card),
            ?sectionBody,
          ],
        ),
      ),
    );
    final top = gapAbove;
    final foldNear = Color.alphaBlend(DesignColors.tint(tone.haloBase, Alpha.v40), DesignColors.surface);
    final foldFar = Color.alphaBlend(DesignColors.tint(tone.haloBase, Alpha.v25), DesignColors.surface);
    final layerH = DS.s(16);
    final layerRoom = folded ? DS.s(34) : 0.0;
    final bottom = math.max(0.0, layerRoom - gapBelow);
    final layerBox = DS.s(30);
    Widget layer(double inset, double drop, Color color, List<BoxShadow>? shadow) => Positioned(
          left: side + DS.s(inset),
          right: side + DS.s(inset),
          bottom: layerBox - DS.s(drop),
          height: layerH,
          child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: DS.br(_layerRadius), boxShadow: shadow)),
        );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(padding: EdgeInsets.fromLTRB(side, top, side, bottom), child: section),
        if (folded)
          Positioned(
            key: layersKey,
            left: 0,
            right: 0,
            bottom: bottom - layerBox,
            height: layerBox,
            child: IgnorePointer(
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    layer(30, 20, foldFar, null),
                    layer(16, 10, foldNear, DS.shadows([BoxShadow(color: tone.haloBase.withValues(alpha: Alpha.v25), offset: const Offset(0, 3), blurRadius: 6)])),
                  ],
                ),
              ),
            ),
          ),
        if (folded)
          Positioned(
            left: side + DS.s(16),
            right: side + DS.s(16),
            bottom: bottom,
            height: DS.s(2),
            child: IgnorePointer(child: ColoredBox(color: foldNear)),
          ),
      ],
    );
  }
}

class _FoldChevron extends CustomPainter {
  const _FoldChevron(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final path = Path()
      ..moveTo(6 * k, 15 * k)
      ..lineTo(12 * k, 9 * k)
      ..lineTo(18 * k, 15 * k);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * k
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_FoldChevron old) => old.color != color;
}
