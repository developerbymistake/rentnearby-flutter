import 'package:flutter/material.dart';

import '../tokens/listing_palette.dart';
import 'art_3d.dart';
import 'meals_card_v.dart';
import 'motion_kit.dart';
import 'pill_buttons_3d.dart';
import '../tokens/design_scale.dart';

abstract final class JourneyArt {
  static const String automobile = 'assets/images/design/travel3d/automobile.png';

  static String forVehicle(String? name, [int? seats]) {
    final v = (name ?? '').toLowerCase();
    if (v.contains('bus') || v.contains('tempo') || v.contains('traveller') || v.contains('traveler') || (seats ?? 0) >= 10) return ListingArt.bus;
    if (v.contains('suv') || v.contains('innova') || v.contains('ertiga') || v.contains('scorpio') || (seats ?? 0) >= 6) return automobile;
    return ListingArt.taxi;
  }
}

abstract final class JourneyInk {
  static List<BoxShadow> get sheetShadow => [BoxShadow(color: Color(0x2E000000), offset: DS.shadowOffset(const Offset(0, -4)), blurRadius: DS.shadowBlur(24))];
  static const Color ok = Color(0xFF2E7D32);
  static const Color bad = Color(0xFFC2410C);
  static const Color booked = Color(0xFF2633C5);
  static const Color changeLine = Color(0xFFF57C00);
  static const Color warnLine = Color(0xFFFF8A3D);
  static const Color warnFill = Color(0xFFFFF1DE);
  static const Color warnText = Color(0xFF6A4A1A);
  static const Color errFill = Color(0xFFFFE9EA);
  static const Color errText = Color(0xFF9E2A30);
  static const Color lowFill = Color(0xFFE3F4E4);
  static const Color radioOff = Color(0xFFD5D8E0);
  static const Color skeleton = Color(0xFFEFE6E3);

  static ListingTone legTone(int legIndex, {bool unavailable = false}) {
    if (unavailable) return ListingTone.cF;
    return ListingTone.list(ListingTone.coral, (legIndex - 1).abs());
  }

  static Color lineFor(ListingTone t) => identical(t, ListingTone.cF) ? warnLine : t.g1;
}

class JourneyHeader3D extends StatelessWidget {
  const JourneyHeader3D({super.key, required this.title, this.subtitle, this.art = ListingArt.clipboard, this.onBack, this.bottom, this.tone});

  final String title;
  final String? subtitle;
  final String art;
  final VoidCallback? onBack;
  final Widget? bottom;
  final ListingTone? tone;

  Widget _head(BuildContext context) {
    final t = tone ?? ListingTone.coral;
    final w = MediaQuery.sizeOf(context).width;
    final narrow = w < 340;
    final size = narrow ? 57.0 : (w < 380 ? 68.0 : 77.0);
    final sub = subtitle;
    final back = Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      excludeFromSemantics: true,
      child: Tap3D(
        onTap: onBack ?? () => Navigator.of(context).maybePop(),
        label: MaterialLocalizations.of(context).backButtonTooltip,
        exclude: true,
        child: Container(
          width: DS.s(46),
          height: DS.s(46),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: DS.shadows(Ink3D.softShadow)),
          child: Icon(Icons.chevron_left_rounded, size: DS.s(28), color: t.text),
        ),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(6), DS.s(12), 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(right: 0, top: 0, child: ExcludeSemantics(child: Art3D(asset: art, size: size, halo: size - 6, haloColor: t.halo, haloDy: 4))),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: DS.s(size - 6)),
            child: Padding(
              padding: EdgeInsets.only(right: DS.s(size + 4)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    back,
                    Gap.h(12),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(narrow ? 20 : 22, FontWeight.w700, Ink3D.title, height: 1.2)),
                      ),
                    ),
                  ]),
                  if (sub != null && sub.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(left: DS.s(58)),
                      child: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub, height: 1.4)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(DS.radius(32))),
        boxShadow: [BoxShadow(color: Color(0x409E9E9E), offset: DS.shadowOffset(const Offset(0, 6)), blurRadius: DS.shadowBlur(16))],
      ),
      child: Padding(
        padding: EdgeInsets.only(top: top, bottom: DS.gv(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _head(context),
            if (bottom != null) Padding(padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(4), DS.s(16), 0), child: bottom),
          ],
        ),
      ),
    );
  }
}

class JourneyChip3D extends StatelessWidget {
  const JourneyChip3D({super.key, required this.label, this.onTap, this.filled = false, this.tone, this.icon, this.busy = false});

  final String label;
  final VoidCallback? onTap;
  final bool filled;
  final ListingTone? tone;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.coral;
    final fg = filled ? Colors.white : Ink3D.copy;
    final chip = Container(
      constraints: BoxConstraints(minHeight: DS.s(44)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(16), vertical: DS.s(8)),
      decoration: BoxDecoration(
        color: filled ? null : Form3D.fill,
        gradient: filled ? t.gradient : null,
        borderRadius: DS.circular(22),
        boxShadow: filled ? [BoxShadow(color: t.shadow, offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(8))] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            Padding(padding: EdgeInsets.only(right: DS.s(6)), child: SizedBox(width: DS.s(14), height: DS.s(14), child: CircularProgressIndicator(strokeWidth: DS.s(2), color: fg)))
          else if (icon != null)
            Padding(padding: EdgeInsets.only(right: DS.s(4)), child: Icon(icon, size: DS.s(16), color: fg)),
          Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, fg, letterSpacing: 0))),
        ],
      ),
    );
    if (onTap == null) return chip;
    return Tap3D(onTap: busy ? null : onTap, label: label, child: chip);
  }
}

class JourneyPill3D extends StatelessWidget {
  const JourneyPill3D({super.key, required this.label, this.ink});

  final String label;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final on = ink != null;
    return DecoratedBox(
      decoration: BoxDecoration(color: on ? Colors.white : Colors.white.withValues(alpha: 0.26), borderRadius: DS.circular(10)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: DS.s(10), vertical: DS.s(3)),
        child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w700, ink ?? Colors.white)),
      ),
    );
  }
}

class JourneyCell {
  const JourneyCell({required this.label, this.icon, this.onTap, this.busy = false, this.itemKey});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;
  final Key? itemKey;
}

class _Metrics {
  const _Metrics(this.top, this.left, this.headMin, this.art, this.halo, this.artAt, this.haloAt);

  final double top;
  final double left;
  final double headMin;
  final double art;
  final double halo;
  final Offset artAt;
  final Offset haloAt;

  static _Metrics of(double width, double scale) {
    final narrow = width < 340;
    if (narrow && scale > 1.15) return const _Metrics(50, 104, 84, 90, 94, Offset(4, -32), Offset(2, -28));
    if (narrow) return const _Metrics(56, 124, 92, 108, 112, Offset(4, -38), Offset(2, -32));
    if (width < 400) return const _Metrics(60, 146, 100, 128, 132, Offset(6, -46), Offset(4, -40));
    return const _Metrics(60, 160, 100, 144, 148, Offset(6, -52), Offset(4, -46));
  }
}

// Gradient wide card with fixed slots: tag, title, sub lines, pill, fare, note strip, 2-cell bar.
class JourneyCard3D extends StatelessWidget {
  const JourneyCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.tag,
    this.subtitle = const [],
    this.pill,
    this.fare,
    this.fareCaption = 'FARE',
    this.note = const [],
    this.noteLines = 1,
    this.cells = const [null, null],
    this.onTap,
    this.semanticsLabel,
    this.picked = false,
    this.linkAbove,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String? tag;
  final List<String> subtitle;
  final Widget? pill;
  final Color? linkAbove;
  final String? fare;
  final String fareCaption;
  final List<String> note;
  final int noteLines;
  final List<JourneyCell?> cells;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final scaler = MediaQuery.textScalerOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final m = _Metrics.of(width, scaler.scale(1));
    final hasTag = tag != null && tag!.isNotEmpty;
    final tagStyle = Ink3D.text(10.5, FontWeight.w700, white.withValues(alpha: 0.9), letterSpacing: 0.6);
    final head = ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(m.headMin)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(m.left), DS.s(20), DS.s(18), 0),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: DS.gv(2)),
                child: Visibility(
                  visible: hasTag,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: Text(hasTag ? tag!.toUpperCase() : ' ', maxLines: 2, overflow: TextOverflow.ellipsis, style: tagStyle),
                ),
              ),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(width < 340 ? 18 : 20, FontWeight.w700, white, height: 1.2)),
              for (final (i, l) in subtitle.indexed)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? DS.gv(4) : 0),
                  child: Text(l, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, white.withValues(alpha: 0.96), height: 1.45)),
                ),
            ],
          ),
        ),
      ),
    );
    final pillRow = Padding(
      padding: EdgeInsets.fromLTRB(DS.s(20), DS.s(12), DS.s(20), 0),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: scaler.scale(DS.s(24))),
        child: Align(alignment: Alignment.topLeft, child: pill ?? const SizedBox.shrink()),
      ),
    );
    final fareRow = fare == null
        ? null
        : Padding(
            padding: EdgeInsets.fromLTRB(DS.s(20), DS.s(12), DS.s(20), 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.only(right: DS.s(6), bottom: DS.s(5)),
                  child: Text(fareCaption, style: Ink3D.text(11, FontWeight.w700, white.withValues(alpha: 0.9), letterSpacing: 0.5)),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(fare!, maxLines: 1, style: Ink3D.text(28, FontWeight.w500, white, height: 1)),
                  ),
                ),
              ],
            ),
          );
    final noteStyle = Ink3D.text(12.5, FontWeight.w500, white, height: 1.35);
    final lines = note.where((e) => e.isNotEmpty).toList();
    final strip = noteLines == 0 && lines.isEmpty
        ? null
        : Container(
      margin: EdgeInsets.only(top: DS.gv(12)),
      padding: EdgeInsets.symmetric(horizontal: DS.s(20), vertical: DS.s(9)),
      color: Colors.black.withValues(alpha: 0.11),
      child: Row(
        children: [
          Visibility(
            visible: lines.isNotEmpty,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Transform.translate(
              offset: Offset(DS.s(-4), 0),
              child: const Art3D(asset: ListingArt.roundPushpin, size: 20, shadowBlur: 2, shadowOffset: Offset(1, 2), shadowAlpha: 0.3),
            ),
          ),
          Gap.h(4),
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: scaler.scale(DS.f(12.5)) * 1.35 * (noteLines < 1 ? 1 : noteLines)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [for (final l in lines) Text(l, maxLines: 3, overflow: TextOverflow.ellipsis, style: noteStyle)],
              ),
            ),
          ),
        ],
      ),
    );
    final bar = cells.isEmpty
        ? null
        : DecoratedBox(
            decoration: BoxDecoration(color: white.withValues(alpha: 0.2)),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cells.length; i++) ...[
                    if (i > 0) Container(width: 1, color: white.withValues(alpha: 0.28)),
                    Expanded(child: _Cell(cell: cells[i])),
                  ],
                ],
              ),
            ),
          );
    final cardBox = Container(
      decoration: BoxDecoration(
        borderRadius: DS.br(kMealsRadius),
        gradient: tone.gradient,
        boxShadow: picked ? [BoxShadow(color: tone.shadow, offset: DS.shadowOffset(const Offset(1.1, 6)), blurRadius: DS.shadowBlur(14))] : tone.glow(),
      ),
      foregroundDecoration: picked
          ? BoxDecoration(borderRadius: DS.br(kMealsRadius), border: Border.all(color: white, width: DS.s(3), strokeAlign: BorderSide.strokeAlignOutside))
          : null,
      child: ClipRRect(
        borderRadius: DS.br(kMealsRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [head, pillRow, ?fareRow, ?strip, if (strip == null && bar != null) Gap.v(14), ?bar, if (bar == null) Gap.v(4)],
        ),
      ),
    );
    Widget body = Stack(
      clipBehavior: Clip.none,
      children: [
        if (linkAbove != null) Positioned(left: DS.s(56), top: 0, width: DS.s(4), height: DS.s(m.top + m.haloAt.dy + 6), child: ColoredBox(color: linkAbove!)),
        Padding(padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(m.top), DS.s(14), DS.s(8)), child: cardBox),
        Positioned(
          left: DS.s(14 + m.haloAt.dx),
          top: DS.s(m.top + m.haloAt.dy),
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: 0.24)),
              child: SizedBox(width: DS.s(m.halo), height: DS.s(m.halo)),
            ),
          ),
        ),
        Positioned(left: DS.s(14 + m.artAt.dx), top: DS.s(m.top + m.artAt.dy), child: IgnorePointer(child: Art3D(asset: art, size: m.art))),
      ],
    );
    if (onTap != null) body = PressScale(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: body));
    if (semanticsLabel == null) return body;
    return Semantics(label: semanticsLabel, container: true, child: body);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.cell});

  final JourneyCell? cell;

  @override
  Widget build(BuildContext context) {
    final c = cell;
    if (c == null) return SizedBox(height: DS.s(52));
    final enabled = c.onTap != null && !c.busy;
    final inner = ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(52)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: DS.s(8), vertical: DS.s(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (c.icon != null || c.busy) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Color(0x40000000), offset: DS.shadowOffset(const Offset(3, 4)), blurRadius: DS.shadowBlur(6))],
                ),
                child: SizedBox(
                  width: DS.s(26),
                  height: DS.s(26),
                  child: c.busy
                      ? Padding(padding: DS.all(6), child: CircularProgressIndicator(strokeWidth: DS.s(2), color: Ink3D.body))
                      : Icon(c.icon, size: DS.s(14), color: Ink3D.body),
                ),
              ),
              Gap.h(8),
            ],
            Flexible(
              child: Text(c.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, Colors.white, height: 1.2)),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: c.label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || c.busy ? 1 : 0.5,
        child: GestureDetector(key: c.itemKey, behavior: HitTestBehavior.opaque, onTap: enabled ? c.onTap : null, child: inner),
      ),
    );
  }
}

class JourneyCardSkeleton extends StatelessWidget {
  const JourneyCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    const bone = JourneyInk.skeleton;
    Widget box(double w, double h, [double r = 14]) => Container(width: DS.s(w), height: DS.s(h), decoration: BoxDecoration(color: bone, borderRadius: DS.circular(r)));
    final left = DS.s(narrow ? 124.0 : 156.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(58), DS.s(14), DS.s(8)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: DS.s(172),
            decoration: BoxDecoration(color: Colors.white, borderRadius: DS.br(kMealsRadius), boxShadow: DS.shadows(Form3D.cardShadow)),
          ),
          Positioned(left: DS.s(8), top: DS.s(-46), child: box(narrow ? 108 : 140, narrow ? 108 : 140, 70)),
          Positioned(left: left, top: DS.s(26), child: box(narrow ? 110 : 150, 18)),
          Positioned(left: left, top: DS.s(56), child: box(110, 13)),
          Positioned(left: left, top: DS.s(80), child: box(narrow ? 100 : 130, 13)),
          Positioned(left: DS.s(20), right: DS.s(20), bottom: DS.s(16), child: box(double.infinity, 30, 15)),
        ],
      ),
    );
  }
}

class JourneyPillSkeleton extends StatelessWidget {
  const JourneyPillSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: DS.s(44),
        margin: EdgeInsets.fromLTRB(DS.s(16), DS.gv(18), DS.s(16), 0),
        decoration: BoxDecoration(color: JourneyInk.skeleton, borderRadius: DS.circular(22)),
      );
}

class JourneyEmpty3D extends StatelessWidget {
  const JourneyEmpty3D({
    super.key,
    required this.art,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.tone,
    this.compact = false,
    this.artSize,
  });

  final double? artSize;
  final String art;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final ListingTone? tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = tone ?? ListingTone.coral;
    final size = artSize ?? (compact ? 142.0 : 180.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(30), artSize != null ? DS.s(8) : (compact ? DS.s(18) : DS.s(40)), DS.s(30), DS.s(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Art3D(asset: art, size: size, halo: size - 2, haloColor: t.halo, shadowBlur: 10, shadowOffset: const Offset(8, 12)),
          Gap.v(compact ? 12 : 16),
          Text(title, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(compact ? 19 : 22, FontWeight.w700, Ink3D.title, height: 1.25)),
          if (body != null && body!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(6)),
              child: Text(body!, textAlign: TextAlign.center, style: Ink3D.text(14.5, FontWeight.w400, Ink3D.copy, height: 1.45)),
            ),
          if (actionLabel != null)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(22)),
              child: SizedBox(width: DS.s(230), child: GradientPillButton(tone: t, label: actionLabel!, onTap: onAction, height: 52, fontSize: 15)),
            ),
          if (secondaryLabel != null)
            Padding(
              padding: EdgeInsets.only(top: DS.gv(12)),
              child: SizedBox(width: DS.s(230), child: WhitePillButton(tone: t, label: secondaryLabel!, onTap: onSecondary, height: 52, fontSize: 15)),
            ),
        ],
      ),
    );
  }
}

class JourneyStop3D extends StatelessWidget {
  const JourneyStop3D({super.key, required this.title, this.subtitle, this.art = ListingArt.roundPushpin, this.change = false, this.tag, this.top = 30});

  final String title;
  final String? subtitle;
  final String art;
  final bool change;
  final String? tag;
  final double top;

  @override
  Widget build(BuildContext context) {
    final tile = SizedBox(
      width: DS.s(56),
      height: DS.s(56),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: change ? Colors.white.withValues(alpha: 0.55) : ListingTone.coral.haloBase.withValues(alpha: 0.14),
                borderRadius: DS.circular(18),
              ),
            ),
          ),
          Positioned(left: DS.s(-4), top: DS.s(-14), child: Art3D(asset: art, size: 66, shadowBlur: 4, shadowOffset: const Offset(3, 5), shadowAlpha: 0.28)),
        ],
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(14), DS.gv(top), DS.s(14), 0),
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(change ? 84 : 72)),
        padding: EdgeInsets.symmetric(horizontal: DS.s(16), vertical: DS.s(12)),
        decoration: BoxDecoration(
          color: change ? null : Colors.white,
          gradient: change ? const LinearGradient(colors: [Color(0xFFFFE7C2), Color(0xFFFFD59A)], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(24)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
          boxShadow: [
            change
                ? BoxShadow(color: Color(0x4DF57C00), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(10))
                : BoxShadow(color: Color(0x409E9E9E), offset: DS.shadowOffset(const Offset(1.1, 1.1)), blurRadius: DS.shadowBlur(10)),
          ],
        ),
        child: Row(
          children: [
            tile,
            Gap.h(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, change ? const Color(0xFF5A3500) : Ink3D.title)),
                  if (tag != null) Text(tag!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, const Color(0xFFB35C00))),
                  if (subtitle != null)
                    Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(change ? 12 : 12.5, FontWeight.w400, change ? const Color(0xFF6A4A1A) : Ink3D.sub)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JourneyLink3D extends StatelessWidget {
  const JourneyLink3D({super.key, required this.color, this.height = 26});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(margin: EdgeInsets.only(left: DS.s(56)), width: DS.s(4), height: DS.s(height), color: color),
      );
}

class JourneyTripCard3D extends StatelessWidget {
  const JourneyTripCard3D({super.key, required this.text, required this.actionLabel, this.onAction});

  final String text;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = ListingTone.indigo;
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(30), DS.s(14), 0),
      child: Container(
        constraints: BoxConstraints(minHeight: DS.s(72)),
        padding: EdgeInsets.symmetric(horizontal: DS.s(16), vertical: DS.s(12)),
        decoration: BoxDecoration(
          gradient: t.gradient,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(24)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
          boxShadow: [BoxShadow(color: Color(0x805C5EDD), offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(10))],
        ),
        child: Row(
          children: [
            SizedBox(
              width: DS.s(56),
              height: DS.s(56),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: DS.circular(18)))),
                  Positioned(left: DS.s(-4), top: DS.s(-14), child: Art3D(asset: ListingArt.luggage, size: 66, shadowBlur: 4, shadowOffset: Offset(3, 5), shadowAlpha: 0.28)),
                ],
              ),
            ),
            Gap.h(14),
            Expanded(child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, Colors.white, height: 1.35))),
            Gap.h(8),
            Tap3D(
              onTap: onAction,
              label: actionLabel,
              child: Container(
                constraints: BoxConstraints(minHeight: DS.s(44), minWidth: DS.s(64)),
                alignment: Alignment.center,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: DS.s(13), vertical: DS.s(8)),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(18), boxShadow: DS.shadows(Ink3D.whiteBtn)),
                  child: Text(actionLabel, maxLines: 1, softWrap: false, style: Ink3D.text(12.5, FontWeight.w700, t.g2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JourneyTotalCard3D extends StatelessWidget {
  const JourneyTotalCard3D({super.key, required this.title, required this.caption});

  final String title;
  final String caption;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.fromLTRB(DS.s(14), DS.gv(22), DS.s(14), 0),
        padding: EdgeInsets.symmetric(horizontal: DS.s(16), vertical: DS.s(14)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(24)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
          boxShadow: [BoxShadow(color: Color(0x409E9E9E), offset: DS.shadowOffset(const Offset(1.1, 1.1)), blurRadius: DS.shadowBlur(10))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Ink3D.text(16, FontWeight.w700, Ink3D.title)),
            Gap.v(2),
            Text(caption, style: Ink3D.text(12, FontWeight.w400, Ink3D.grey)),
          ],
        ),
      );
}

class JourneyBanner3D extends StatelessWidget {
  const JourneyBanner3D({super.key, required this.text, this.art = ListingArt.worldMap, this.error = false, this.title, this.linkLabel, this.onLink, this.button});

  final String text;
  final String art;
  final bool error;
  final String? title;
  final String? linkLabel;
  final VoidCallback? onLink;
  final Widget? button;

  @override
  Widget build(BuildContext context) {
    final fg = error ? JourneyInk.errText : JourneyInk.warnText;
    final row = Row(
      children: [
        Art3D(asset: art, size: 34, shadowBlur: 2, shadowOffset: const Offset(1, 2), shadowAlpha: 0.25),
        Gap.h(10),
        Expanded(
          child: title == null
              ? Text(text, style: Ink3D.text(13, FontWeight.w600, fg, height: 1.35))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title!, style: Ink3D.text(13, FontWeight.w700, fg, height: 1.35)),
                    Text(text, style: Ink3D.text(13, FontWeight.w500, fg, height: 1.35)),
                  ],
                ),
        ),
        if (linkLabel != null)
          Tap3D(
            onTap: onLink,
            label: linkLabel,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: DS.s(44), minHeight: DS.s(44)),
              child: Center(widthFactor: 1, child: Padding(padding: EdgeInsets.only(left: DS.s(8)), child: Text(linkLabel!, style: Ink3D.text(13, FontWeight.w700, ListingTone.coral.text)))),
            ),
          ),
      ],
    );
    return Container(
      margin: EdgeInsets.fromLTRB(DS.s(16), DS.gv(14), DS.s(16), 0),
      padding: EdgeInsets.fromLTRB(DS.s(14), linkLabel == null ? DS.s(12) : DS.s(4), DS.s(14), linkLabel == null ? DS.s(12) : DS.s(4)),
      decoration: BoxDecoration(
        color: error ? JourneyInk.errFill : JourneyInk.warnFill,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(24)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
        boxShadow: [BoxShadow(color: Color(0x339E9E9E), offset: DS.shadowOffset(const Offset(1.1, 1.1)), blurRadius: DS.shadowBlur(10))],
      ),
      child: button == null
          ? row
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [row, Gap.v(10), button!]),
    );
  }
}

class JourneyDock3D extends StatelessWidget {
  const JourneyDock3D({super.key, required this.children, this.maxWidth = 720});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(16))),
        boxShadow: [BoxShadow(color: Color(0x599E9E9E), offset: DS.shadowOffset(const Offset(0, -2)), blurRadius: DS.shadowBlur(16))],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(14), DS.s(18), DS.s(16) + bottom),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: DS.s(maxWidth)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      ),
    );
  }
}

class JourneyPayLine extends StatelessWidget {
  const JourneyPayLine(this.text, {super.key, this.center = true});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: DS.gv(8)),
        child: Text(text, textAlign: center ? TextAlign.center : TextAlign.start, style: Ink3D.text(11, FontWeight.w400, Ink3D.grey, height: 1.35)),
      );
}

class JourneyBookRow3D extends StatelessWidget {
  const JourneyBookRow3D({super.key, required this.label, this.onTap, this.booked = false});

  final String label;
  final VoidCallback? onTap;
  final bool booked;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      constraints: BoxConstraints(minHeight: DS.s(46)),
      margin: EdgeInsets.fromLTRB(DS.s(14), DS.gv(10), DS.s(14), 0),
      padding: EdgeInsets.symmetric(horizontal: DS.s(16), vertical: DS.s(8)),
      decoration: BoxDecoration(color: Colors.white, borderRadius: DS.circular(23), boxShadow: [BoxShadow(color: Color(0x599E9E9E), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(10))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (booked) ...[Icon(Icons.check_circle_rounded, size: DS.s(18), color: ListingTone.coral.text), Gap.h(8)],
          Flexible(child: Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, ListingTone.coral.text))),
        ],
      ),
    );
    if (booked) return Opacity(opacity: 0.6, child: pill);
    return Tap3D(onTap: onTap, label: label, child: pill);
  }
}

class JourneySlimCard3D extends StatelessWidget {
  const JourneySlimCard3D({
    super.key,
    required this.tone,
    required this.art,
    required this.title,
    this.tag,
    this.subtitle = const [],
    this.onCall,
    this.callTooltip = 'Call',
    this.picked = false,
    this.onTap,
    this.semanticsLabel,
  });

  final ListingTone tone;
  final String art;
  final String title;
  final String? tag;
  final List<String> subtitle;
  final VoidCallback? onCall;
  final String callTooltip;
  final bool picked;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final art = narrow ? 96.0 : 120.0;
    final left = DS.s(narrow ? 108.0 : 134.0);
    final card = Container(
      constraints: BoxConstraints(minHeight: DS.s(108)),
      padding: EdgeInsets.fromLTRB(left, DS.s(14), DS.s(70), DS.s(14)),
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: DS.br(kMealsRadius),
        boxShadow: picked ? [BoxShadow(color: tone.shadow, offset: DS.shadowOffset(const Offset(1.1, 6)), blurRadius: DS.shadowBlur(14))] : tone.glow(),
      ),
      foregroundDecoration: picked ? BoxDecoration(borderRadius: DS.br(kMealsRadius), border: Border.all(color: white, width: DS.s(3), strokeAlign: BorderSide.strokeAlignOutside)) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag != null) Text(tag!.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w700, white.withValues(alpha: 0.9), letterSpacing: 0.6)),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, white, height: 1.25)),
          for (final l in subtitle) Text(l, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w500, white.withValues(alpha: 0.96), height: 1.45)),
        ],
      ),
    );
    final call = Tooltip(
      message: callTooltip,
      excludeFromSemantics: true,
      child: Tap3D(
        onTap: onCall,
        label: callTooltip,
        child: Opacity(
          opacity: onCall == null ? 0.5 : 1,
          child: Container(
            width: DS.s(44),
            height: DS.s(44),
            decoration: BoxDecoration(color: Color(0xFFFAFAFA), shape: BoxShape.circle, boxShadow: DS.shadows(Ink3D.goBtn)),
            child: Icon(Icons.call_rounded, size: DS.s(20), color: tone.button),
          ),
        ),
      ),
    );
    Widget body = Padding(
      padding: EdgeInsets.fromLTRB(DS.s(16), DS.s(46), DS.s(16), 0),
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          card,
          Positioned(left: DS.s(4), top: DS.s(-30), child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: 0.24)), child: SizedBox(width: DS.s(art - 2), height: DS.s(art - 2))))),
          Positioned(left: DS.s(6), top: DS.s(-36), child: IgnorePointer(child: Art3D(asset: this.art, size: art))),
          Positioned(right: DS.s(18), top: 0, bottom: 0, child: Center(child: call)),
        ],
      ),
    );
    if (onTap != null) {
      body = Semantics(
        button: true,
        selected: picked,
        label: semanticsLabel,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: body),
      );
    }
    return body;
  }
}

class JourneyLegTile3D extends StatelessWidget {
  const JourneyLegTile3D({super.key, required this.art, required this.route, this.tag, this.fare, this.names, this.badge, this.notes = const []});

  final String art;
  final String route;
  final String? tag;
  final String? fare;
  final String? names;
  final String? badge;
  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final t = ListingTone.coral;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    return Padding(
      padding: EdgeInsets.only(top: DS.gv(22)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: BoxConstraints(minHeight: DS.s(112)),
            padding: EdgeInsets.fromLTRB(narrow ? DS.s(84) : DS.s(104), DS.s(12), DS.s(14), DS.s(12)),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(24)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
              boxShadow: [BoxShadow(color: Color(0x4D9E9E9E), offset: DS.shadowOffset(const Offset(1.1, 1.1)), blurRadius: DS.shadowBlur(10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text((tag ?? '').toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w700, t.text, letterSpacing: 0.5))),
                    if (fare != null) Text(fare!, style: Ink3D.text(15, FontWeight.w700, Ink3D.title)),
                  ],
                ),
                Text(route, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, Ink3D.title)),
                if (names != null || badge != null)
                  Padding(
                    padding: EdgeInsets.only(top: DS.gv(6)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: Text(names ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, Ink3D.title))),
                        if (badge != null) ...[
                          Gap.h(6),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: DS.s(8), vertical: DS.s(3)),
                            decoration: BoxDecoration(color: t.haloBase.withValues(alpha: 0.14), borderRadius: DS.circular(10)),
                            child: Text(badge!, maxLines: 1, style: Ink3D.text(11, FontWeight.w700, t.text)),
                          ),
                        ],
                      ],
                    ),
                  ),
                for (final (i, n) in notes.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? DS.gv(6) : 0),
                    child: Text(n, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, height: 1.4)),
                  ),
              ],
            ),
          ),
          Positioned(left: DS.s(8), top: DS.s(-14), child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: t.halo), child: SizedBox(width: DS.s(narrow ? 70 : 86), height: DS.s(narrow ? 70 : 86))))),
          Positioned(left: DS.s(4), top: DS.s(-20), child: IgnorePointer(child: Art3D(asset: art, size: narrow ? 76 : 94, shadowBlur: 5, shadowOffset: const Offset(4, 7), shadowAlpha: 0.28))),
        ],
      ),
    );
  }
}

class JourneyNoteBox3D extends StatelessWidget {
  const JourneyNoteBox3D({super.key, required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: DS.gv(10)),
        constraints: BoxConstraints(minHeight: DS.s(56)),
        padding: EdgeInsets.symmetric(horizontal: DS.s(12), vertical: DS.s(10)),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: error ? JourneyInk.errFill : JourneyInk.warnFill, borderRadius: DS.circular(12)),
        child: Row(
          children: [
            if (!error) ...[Icon(Icons.warning_amber_rounded, size: DS.s(16), color: JourneyInk.warnText), Gap.h(8)],
            Expanded(child: Text(text, style: Ink3D.text(12.5, FontWeight.w600, error ? JourneyInk.errText : JourneyInk.warnText, height: 1.4))),
          ],
        ),
      );
}

class JourneyFilterPill3D extends StatelessWidget {
  const JourneyFilterPill3D({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ListingTone.coral;
    return Tap3D(
      onTap: onTap,
      label: label,
      selected: selected,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: DS.s(44)),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Container(
            constraints: BoxConstraints(minHeight: DS.s(36)),
            padding: EdgeInsets.symmetric(horizontal: DS.s(10), vertical: DS.s(9)),
            decoration: BoxDecoration(
              color: selected ? null : Colors.white,
              gradient: selected ? t.gradient : null,
              borderRadius: DS.circular(18),
              boxShadow: selected ? [BoxShadow(color: t.shadow, offset: DS.shadowOffset(const Offset(1.1, 4)), blurRadius: DS.shadowBlur(8))] : [BoxShadow(color: Color(0x4D9E9E9E), offset: DS.shadowOffset(const Offset(3, 5)), blurRadius: DS.shadowBlur(10))],
            ),
            child: Text(label, maxLines: 1, style: Ink3D.text(11, FontWeight.w700, selected ? Colors.white : t.text, letterSpacing: 0)),
          ),
        ),
      ),
    );
  }
}

class JourneyDriverPick3D extends StatelessWidget {
  const JourneyDriverPick3D({super.key, required this.art, required this.name, this.subtitle, this.fare, this.current = false, this.lowest = false, this.currentLabel = 'current', this.lowestLabel = 'lowest price', this.onTap});

  final String art;
  final String name;
  final String? subtitle;
  final String? fare;
  final bool current;
  final bool lowest;
  final String currentLabel;
  final String lowestLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = ListingTone.coral;
    Widget tag(String text, Color bg, Color fg) => Container(
          margin: EdgeInsets.only(top: DS.gv(3), right: DS.s(6)),
          padding: EdgeInsets.symmetric(horizontal: DS.s(8), vertical: DS.s(1)),
          decoration: BoxDecoration(color: bg, borderRadius: DS.circular(8)),
          child: Text(text, style: Ink3D.text(10.5, FontWeight.w700, fg)),
        );
    final tags = [
      if (current) tag(currentLabel, t.haloBase.withValues(alpha: 0.16), t.text),
      if (lowest) tag(lowestLabel, JourneyInk.lowFill, JourneyInk.ok),
    ];
    return Tap3D(
      onTap: onTap,
      label: name,
      selected: current,
      child: Container(
        margin: EdgeInsets.only(top: DS.gv(10)),
        constraints: BoxConstraints(minHeight: DS.s(74)),
        padding: EdgeInsets.symmetric(horizontal: DS.s(14), vertical: DS.s(8)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(24)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
          border: Border.all(color: current ? t.g2 : Colors.transparent, width: DS.s(2.5)),
          boxShadow: [BoxShadow(color: Color(0x479E9E9E), offset: DS.shadowOffset(const Offset(1.1, 1.1)), blurRadius: DS.shadowBlur(10))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: DS.s(50),
              height: DS.s(50),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: t.haloBase.withValues(alpha: 0.16), borderRadius: DS.circular(16)))),
                  Positioned(left: DS.s(-4), top: DS.s(-6), child: Art3D(asset: art, size: 58, shadowBlur: 3, shadowOffset: const Offset(2, 4), shadowAlpha: 0.25)),
                ],
              ),
            ),
            Gap.h(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, Ink3D.title)),
                  if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w400, Ink3D.grey, height: 1.3)),
                  if (tags.isNotEmpty) Wrap(children: tags),
                ],
              ),
            ),
            Gap.h(8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (fare != null) ConstrainedBox(constraints: BoxConstraints(maxWidth: DS.s(96)), child: FittedBox(fit: BoxFit.scaleDown, child: Text(fare!, style: Ink3D.text(16, FontWeight.w700, Ink3D.title)))),
                Gap.v(4),
                Container(
                  width: DS.s(22),
                  height: DS.s(22),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: current ? t.g2 : JourneyInk.radioOff, width: DS.s(current ? 6 : 2))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class JourneyDriverPickSkeleton extends StatelessWidget {
  const JourneyDriverPickSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget box(double w, double h, double r) => Container(width: DS.s(w), height: DS.s(h), decoration: BoxDecoration(color: JourneyInk.skeleton, borderRadius: DS.circular(r)));
    return Container(
      margin: EdgeInsets.only(top: DS.gv(10)),
      height: DS.s(74),
      padding: EdgeInsets.symmetric(horizontal: DS.s(14), vertical: DS.s(12)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(DS.radius(8)), topRight: Radius.circular(DS.radius(24)), bottomLeft: Radius.circular(DS.radius(8)), bottomRight: Radius.circular(DS.radius(8))),
        boxShadow: [BoxShadow(color: Color(0x479E9E9E), offset: DS.shadowOffset(const Offset(1.1, 1.1)), blurRadius: DS.shadowBlur(10))],
      ),
      child: Row(
        children: [
          box(50, 50, 16),
          Gap.h(12),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [box(130, 14, 7), Gap.v(8), box(150, 11, 6)]),
        ],
      ),
    );
  }
}

// Road timeline row: gutter (line + marker) on the left, content on the right.
enum RoadMark { none, start, end, change }

class JourneyRoadRow extends StatelessWidget {
  const JourneyRoadRow({super.key, required this.child, this.mark = RoadMark.none, this.above, this.below, this.dashedAbove = false, this.dashedBelow = false, this.faded = false});

  final Widget child;
  final RoadMark mark;
  final Color? above;
  final Color? below;
  final bool dashedAbove;
  final bool dashedBelow;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: DS.s(30), child: CustomPaint(painter: _RoadGutter(mark, above, below, dashedAbove, dashedBelow))),
          Gap.h(12),
          Expanded(child: child),
        ],
      ),
    );
    return faded ? Opacity(opacity: 0.38, child: row) : row;
  }
}

class _RoadGutter extends CustomPainter {
  _RoadGutter(this.mark, this.above, this.below, this.dashedAbove, this.dashedBelow);

  final RoadMark mark;
  final Color? above;
  final Color? below;
  final bool dashedAbove;
  final bool dashedBelow;

  @override
  void paint(Canvas canvas, Size size) {
    final x = DS.s(15.5);
    final mid = size.height / 2;
    final p = Paint()..strokeWidth = DS.s(5);
    void line(double a, double b, Color c, bool dashed) {
      p.color = c;
      if (!dashed) {
        canvas.drawLine(Offset(x, a), Offset(x, b), p);
        return;
      }
      var y = a;
      while (y < b) {
        canvas.drawLine(Offset(x, y), Offset(x, (y + DS.s(7)).clamp(a, b)), p);
        y += DS.s(12);
      }
    }

    if (above != null) line(0, mark == RoadMark.none ? size.height : mid, above!, dashedAbove);
    if (below != null) line(mark == RoadMark.none ? 0 : mid, size.height, below!, dashedBelow);
    if (mark == RoadMark.none) return;
    final c = Offset(x, mid);
    switch (mark) {
      case RoadMark.start:
      case RoadMark.end:
        canvas.drawCircle(c, DS.s(12), Paint()..color = (below ?? above ?? ListingTone.coral.g1));
      case RoadMark.change:
        canvas.drawCircle(c, DS.s(12), Paint()..color = const Color(0xFFFFE7C2));
        canvas.drawCircle(c, DS.s(9.5), Paint()
          ..color = JourneyInk.changeLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = DS.s(5));
      case RoadMark.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadGutter o) => o.mark != mark || o.above != above || o.below != below || o.dashedAbove != dashedAbove || o.dashedBelow != dashedBelow;
}

class JourneyRoadPlace extends StatelessWidget {
  const JourneyRoadPlace({super.key, required this.title, this.caption, this.tag, this.note});

  final String title;
  final String? caption;
  final String? tag;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: DS.gv(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, Ink3D.title)),
            if (tag != null) Text(tag!, style: Ink3D.text(12, FontWeight.w700, const Color(0xFFB35C00))),
            if (caption != null) Text(caption!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.sub)),
            if (note != null) Text(note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, Ink3D.sub)),
          ],
        ),
      );
}

class JourneyRoadStretch extends StatelessWidget {
  const JourneyRoadStretch({super.key, required this.tone, required this.art, required this.title, this.lines = const [], this.sketch, this.selected = false, this.onTap});

  final ListingTone tone;
  final String art;
  final String title;
  final List<String> lines;
  final Widget? sketch;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final art = narrow ? 92.0 : 122.0;
    final left = DS.s(narrow ? 100.0 : 128.0);
    final card = Container(
      constraints: BoxConstraints(minHeight: DS.s(118)),
      padding: EdgeInsets.fromLTRB(left, DS.s(16), DS.s(16), DS.s(16)),
      decoration: BoxDecoration(
        gradient: tone.gradient,
        borderRadius: DS.br(kMealsRadius),
        boxShadow: tone.glow(dy: 4, blur: 8),
      ),
      foregroundDecoration: selected ? BoxDecoration(borderRadius: DS.br(kMealsRadius), border: Border.all(color: Colors.white, width: DS.s(3), strokeAlign: BorderSide.strokeAlignOutside)) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, Colors.white, height: 1.25)),
          for (final l in lines)
            Padding(padding: EdgeInsets.only(top: DS.gv(2)), child: Text(l, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w500, Colors.white.withValues(alpha: 0.95), height: 1.4))),
          if (sketch != null) Padding(padding: EdgeInsets.only(top: DS.gv(8)), child: sketch),
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(top: DS.gv(46), bottom: DS.gv(12)),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              Positioned(left: DS.s(4), top: DS.s(-34), child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.22)), child: SizedBox(width: DS.s(art - 6), height: DS.s(art - 6))))),
              Positioned(left: DS.s(2), top: DS.s(-40), child: IgnorePointer(child: Art3D(asset: this.art, size: art))),
            ],
          ),
        ),
      ),
    );
  }
}

class JourneyGapCard3D extends StatelessWidget {
  const JourneyGapCard3D({super.key, required this.title, this.tag, this.body, required this.actionLabel, this.onAction});

  final String title;
  final String? tag;
  final String? body;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = ListingTone.coral;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final art = narrow ? 92.0 : 112.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(58), DS.s(14), 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(22), DS.s(18), DS.s(18)),
            decoration: BoxDecoration(color: Colors.white, borderRadius: DS.br(kMealsRadius), boxShadow: [BoxShadow(color: Color(0x4D9E9E9E), offset: DS.shadowOffset(const Offset(1.1, 1.1)), blurRadius: DS.shadowBlur(10))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: DS.s(62)),
                  child: Padding(
                    padding: EdgeInsets.only(left: DS.s(art + 6)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(16, FontWeight.w700, Ink3D.title, height: 1.3)),
                        if (tag != null) Padding(padding: EdgeInsets.only(top: DS.gv(2)), child: Text(tag!, maxLines: 2, style: Ink3D.text(12.5, FontWeight.w600, t.text))),
                      ],
                    ),
                  ),
                ),
                if (body != null)
                  Padding(padding: EdgeInsets.only(top: DS.gv(12)), child: Text(body!, maxLines: 4, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w400, Ink3D.copy, height: 1.4))),
                Gap.v(16),
                WhitePillButton(tone: t, label: actionLabel, height: 52, fontSize: 15, onTap: onAction),
              ],
            ),
          ),
          Positioned(left: DS.s(8), top: DS.s(-46), child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: t.halo), child: SizedBox(width: DS.s(art), height: DS.s(art))))),
          Positioned(left: DS.s(8), top: DS.s(-50), child: IgnorePointer(child: Art3D(asset: ListingArt.taxi, size: art, shadowBlur: 6, shadowOffset: const Offset(5, 8)))),
        ],
      ),
    );
  }
}

class JourneyRailCard3D extends StatelessWidget {
  const JourneyRailCard3D({
    super.key,
    required this.tone,
    required this.title,
    required this.lines,
    required this.buttonLabel,
    this.art,
    this.photo,
    this.sticker,
    this.number,
    this.unit = '',
    this.onTap,
    this.width = 160,
  });

  final ListingTone tone;
  final String title;
  final List<String> lines;
  final String buttonLabel;
  final String? art;
  final Widget? photo;
  final String? sticker;
  final String? number;
  final String unit;
  final VoidCallback? onTap;
  final double width;

  static EdgeInsets get cellPadding => EdgeInsets.fromLTRB(DS.s(8), DS.s(46), DS.s(8), DS.s(14));

  static double heightFor(BuildContext context) => DS.s(300) + (MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.2) - 1) * DS.s(90);

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2);
    final n = number;
    final card = DecoratedBox(
      decoration: BoxDecoration(borderRadius: DS.br(kMealsRadius), gradient: tone.gradient, boxShadow: tone.glow(blur: 8)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(DS.s(15), DS.s(64), DS.s(15), DS.s(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, white, height: 1.3)),
            Gap.v(4),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: scaler.scale(DS.f(12)) * 1.5 * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in lines.take(2))
                    Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w500, white, height: 1.5)),
                ],
              ),
            ),
            Gap.v(6),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: scaler.scale(DS.s(30))),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: n == null || n.isEmpty ? const SizedBox.shrink() : PriceLine(number: n, unit: unit, numberSize: 24),
              ),
            ),
            Gap.v(8),
            WhitePillButton(tone: tone, label: buttonLabel, onTap: onTap, onGradient: true, height: 34, fontSize: 13),
          ],
        ),
      ),
    );
    final halo = DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: white.withValues(alpha: 0.22)),
      child: SizedBox(width: DS.s(112), height: DS.s(112)),
    );
    final p = photo;
    final a = art;
    final body = SizedBox(
      width: DS.s(width),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(padding: cellPadding, child: card),
          if (p != null) ...[
            Positioned(left: DS.s(6), top: 0, child: IgnorePointer(child: halo)),
            Positioned(left: DS.s(12), top: DS.s(2), child: IgnorePointer(child: PhotoSticker(photo: p, sticker: sticker ?? '', size: 100, stickerSize: 52, stickerOffset: const Offset(66, 64)))),
          ] else if (a != null) ...[
            Positioned(left: DS.s(6), top: 0, child: IgnorePointer(child: halo)),
            Positioned(left: DS.s(8), top: DS.s(-6), child: IgnorePointer(child: Art3D(asset: a, size: 110, shadowBlur: 5, shadowOffset: const Offset(4, 6), shadowAlpha: 0.22))),
          ],
        ],
      ),
    );
    final clamped = MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: scaler), child: Align(alignment: Alignment.topLeft, child: body));
    if (onTap == null) return clamped;
    return PressScale(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: clamped));
  }
}
