import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../utils/money_format.dart';
import '../../../widgets/tab_header.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/money/money_notes_fields.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import 'taxi_trip_text.dart';

abstract final class TaxiCal {
  static const ListingPalette coral = ListingPalette.coral;
  static Color get page => coral.page;
  static Color get accent => coral.text;
  static Color get tileFill => coral.tint;
  static Color get ownDot => coral.g2;
  static const Color appDot = OwnerLook.appDot;
  static const Color festival = OwnerLook.specialBand;
  static Color get greenFill => ListingTone.forest.tint;
  static Color get greenText => ListingTone.forest.text;
  static const Color amber = OwnerLook.amber;
  static const Color amberFill = OwnerLook.amberSoft;
  static const Color greyFill = OwnerLook.greySoft;
  static const Color softFill = OwnerLook.gateBox;
  static Color get tealFill => ListingPalette.teal.tint;
  static Color get tealText => ListingPalette.teal.text;
  static OwnerLook get look => OwnerLook.taxi;
  static KitTone get kit => coral.tone;
  static LinearGradient get hero => coral.gradient;

  static bool get isPlus => PlanGate.paymentOn && !PlanGate.canUpgrade;

  static BoxDecoration card({bool hero = true}) => BoxDecoration(
        color: DesignColors.surface,
        borderRadius: hero ? DS.br(CardRadius.hero) : DS.circular(16),
        boxShadow: DS.shadows(ShadowTokens.elev1),
      );
}

enum TaxiBadgeKind { fromApp, addedByYou, confirmed, cancelled, plus }

class TaxiBadge extends StatelessWidget {
  const TaxiBadge({super.key, required this.kind});

  final TaxiBadgeKind kind;

  static TaxiBadgeKind of(CalendarEntry e) => e.isAuto ? TaxiBadgeKind.fromApp : TaxiBadgeKind.addedByYou;

  @override
  Widget build(BuildContext context) {
    final (text, bg, fg) = switch (kind) {
      TaxiBadgeKind.fromApp => (OwnerSharedStrings.fromApp, TaxiCal.greenFill, TaxiCal.greenText),
      TaxiBadgeKind.addedByYou => (OwnerSharedStrings.addedByYou, TaxiCal.tileFill, TaxiCal.accent),
      TaxiBadgeKind.confirmed => (TaxiCalendarStrings.confirmed, TaxiCal.tileFill, TaxiCal.accent),
      TaxiBadgeKind.cancelled => (OwnerSharedStrings.cancelled, TaxiCal.greyFill, Ink3D.grey),
      TaxiBadgeKind.plus => (OwnerSharedStrings.plus, TaxiCal.tileFill, TaxiCal.accent),
    };
    return Container(
      padding: DS.sym(h: 8, v: 3),
      decoration: BoxDecoration(color: bg, borderRadius: DS.circular(10)),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w700, fg, letterSpacing: 0)),
    );
  }
}

class TaxiPlusPill extends StatelessWidget {
  const TaxiPlusPill({super.key, this.onWhite = true});

  final bool onWhite;

  @override
  Widget build(BuildContext context) {
    if (!TaxiCal.isPlus) return const SizedBox.shrink();
    return Container(
      padding: DS.sym(h: 12, v: 6),
      decoration: BoxDecoration(color: onWhite ? DesignColors.surface : TaxiCal.tileFill, borderRadius: DS.circular(12)),
      child: Text(OwnerSharedStrings.plus, style: Ink3D.text(12, FontWeight.w700, TaxiCal.accent, letterSpacing: 0)),
    );
  }
}

class TaxiDateTile extends StatelessWidget {
  const TaxiDateTile({super.key, required this.top, required this.bottom, this.muted = false});

  final String top;
  final String bottom;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? Ink3D.hint : TaxiCal.accent;
    return Container(
      width: DS.s(46),
      padding: DS.sym(v: 6),
      decoration: BoxDecoration(color: muted ? TaxiCal.greyFill : TaxiCal.tileFill, borderRadius: DS.circular(10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(top, maxLines: 1, style: Ink3D.text(16, FontWeight.w700, color, height: 1.1, letterSpacing: 0))),
          if (bottom.isNotEmpty) Text(bottom, maxLines: 1, style: Ink3D.text(9, FontWeight.w700, color, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class TaxiChip extends StatelessWidget {
  const TaxiChip({super.key, required this.entry, this.markCancelled = true});

  final CalendarEntry entry;
  final bool markCancelled;

  @override
  Widget build(BuildContext context) =>
      BalanceChip(chip: TaxiTripText.chip(entry), amount: TaxiTripText.chipAmount(entry), cancelled: markCancelled && entry.cancelled);
}

class TaxiTripRow extends StatelessWidget {
  const TaxiTripRow({
    super.key,
    required this.entry,
    required this.line,
    this.tile,
    this.trailing,
    this.chipInline = false,
    this.chipBelow = false,
    this.onTap,
    this.badgeTop = false,
    this.padding,
  });

  final CalendarEntry entry;
  final String line;
  final ({String top, String bottom})? tile;
  final Widget? trailing;
  final bool chipInline;
  final bool chipBelow;
  final bool badgeTop;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final t = tile ?? TaxiTripText.dateTile(entry);
    final muted = entry.cancelled;
    final badges = Wrap(
      spacing: DS.gh(6),
      runSpacing: DS.gv(4),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TaxiBadge(kind: TaxiBadge.of(entry)),
        if (chipInline) TaxiChip(entry: entry),
      ],
    );
    final body = Padding(
      padding: padding ?? DS.sym(h: 14, v: 12),
      child: Row(
        children: [
          TaxiDateTile(top: t.top, bottom: t.bottom, muted: muted),
          Gap.h(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badgeTop) ...[badges, Gap.v(4)],
                Text(TaxiTripText.title(entry),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w700, muted ? Ink3D.grey : Ink3D.title, letterSpacing: 0)),
                if (line.isNotEmpty)
                  Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                if (!badgeTop) ...[Gap.v(4), badges],
                if (chipBelow) ...[Gap.v(6), TaxiChip(entry: entry)],
              ],
            ),
          ),
          if (trailing != null) ...[Gap.h(8), trailing!],
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: TaxiTripText.semantics(entry),
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

class TaxiAmount extends StatelessWidget {
  const TaxiAmount({super.key, required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) =>
      Text(Money.exact(amount), maxLines: 1, style: Ink3D.text(14, FontWeight.w700, Ink3D.title, letterSpacing: 0));
}

/// One row of a grouped list drawn inside a white card: top corners on the first row, bottom on the last.
class TaxiCardSegment extends StatelessWidget {
  const TaxiCardSegment({super.key, required this.child, required this.first, required this.last});

  final Widget child;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final r = DS.radius(18);
    final big = DS.radius(CardRadius.heroNotch / 2);
    final radius = BorderRadius.only(
      topLeft: Radius.circular(first ? r : 0),
      topRight: Radius.circular(first ? big : 0),
      bottomLeft: Radius.circular(last ? r : 0),
      bottomRight: Radius.circular(last ? r : 0),
    );
    return Container(
      margin: EdgeInsets.only(bottom: last ? DS.gv(14) : 0),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: radius,
        boxShadow: last ? DS.shadows(ShadowTokens.elev1) : null,
        border: first ? null : Border(top: BorderSide(color: Ink3D.line, width: DS.s(1))),
      ),
      child: ClipRRect(borderRadius: radius, child: Material(color: Colors.transparent, child: child)),
    );
  }
}

class TaxiSectionLabel extends StatelessWidget {
  const TaxiSectionLabel({super.key, required this.text, this.count});

  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 4, t: 6, r: 4, b: 8),
        child: Row(
          children: [
            Expanded(child: Text(text, style: Ink3D.text(11, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8))),
            if (count != null) Text('$count', style: Ink3D.text(11, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          ],
        ),
      );
}

class TaxiTitleRow extends StatelessWidget {
  const TaxiTitleRow({super.key, required this.title, this.sub, this.padding});

  final String title;
  final String? sub;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ?? DS.insets(t: 18, b: 10),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: DS.gh(8),
          children: [
            Text(title, style: Ink3D.text(17, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
            if (sub != null && sub!.isNotEmpty)
              Padding(padding: EdgeInsets.only(bottom: DS.s(2)), child: Text(sub!, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, letterSpacing: 0))),
          ],
        ),
      );
}

class TaxiKv extends StatelessWidget {
  const TaxiKv({super.key, required this.label, this.value, this.trailing, this.divider = true});

  final String label;
  final String? value;
  final Widget? trailing;
  final bool divider;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(v: 9),
        decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: Ink3D.line, width: DS.s(1))) : null),
        child: Semantics(
          label: '$label, ${value ?? ''}',
          excludeSemantics: trailing == null,
          child: Row(
            children: [
              Text(label, style: Ink3D.text(12, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
              Gap.h(12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing ??
                      Text(value ?? TaxiCalendarStrings.dash,
                          textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                ),
              ),
            ],
          ),
        ),
      );
}

class TaxiNoteCard extends StatelessWidget {
  const TaxiNoteCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 14, v: 12),
        decoration: BoxDecoration(color: TaxiCal.tileFill, borderRadius: DS.circular(16)),
        child: Row(
          children: [
            Art3D(asset: ListingArt.pushpin, size: 34),
            Gap.h(12),
            Expanded(child: Text(text, style: Ink3D.text(12, FontWeight.w600, TaxiCal.accent, height: 1.4, letterSpacing: 0))),
          ],
        ),
      );
}

class TaxiShieldNote extends StatelessWidget {
  const TaxiShieldNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 14, v: 12),
        decoration: BoxDecoration(color: TaxiCal.tealFill, borderRadius: DS.circular(14)),
        child: Row(
          children: [
            Art3D(asset: ListingArt.shield, size: 24),
            Gap.h(10),
            Expanded(child: Text(text, style: Ink3D.text(11.5, FontWeight.w600, TaxiCal.tealText, height: 1.4, letterSpacing: 0))),
          ],
        ),
      );
}

class TaxiFootLine extends StatelessWidget {
  const TaxiFootLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.sym(v: 8),
        child: Row(
          children: [
            Art3D(asset: ListingArt.alarmClock, size: 16),
            Gap.h(8),
            Expanded(child: Text(text, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0))),
          ],
        ),
      );
}

class TaxiCalPageHeader extends StatelessWidget {
  const TaxiCalPageHeader({super.key, required this.title, this.subtitle, this.plusPill = false});

  final String title;
  final String? subtitle;
  final bool plusPill;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: ModuleHeader(
          title: title,
          subtitle: subtitle,
          autoHeight: true,
          compact: true,
          tone: TaxiCal.kit,
          gradient: TaxiCal.hero,
          onBack: () => Navigator.of(context).maybePop(),
          trailing: [if (plusPill && TaxiCal.isPlus) const TaxiPlusPill()],
        ),
      );
}

class TaxiTabHeader extends StatelessWidget {
  const TaxiTabHeader({super.key, required this.title, required this.subtitle, this.trailing = const [], this.icons = true});

  final String title;
  final String subtitle;
  final List<Widget> trailing;
  final bool icons;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TaxiCal.page,
      child: Padding(
        padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
        child: Padding(
          padding: DS.insets(l: 18, t: 10, r: 18, b: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      header: true,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(title, maxLines: 1, style: Ink3D.text(28, FontWeight.w700, Ink3D.title, height: 1.25)),
                      ),
                    ),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w400, Ink3D.sub, letterSpacing: 0)),
                  ],
                ),
              ),
              for (final t in trailing) ...[Gap.h(8), t],
              if (icons) ...[Gap.h(8), const TabHeaderIcons()],
            ],
          ),
        ),
      ),
    );
  }
}

class TaxiWhitePillButton extends StatelessWidget {
  const TaxiWhitePillButton({super.key, required this.label, required this.onTap, this.semantics});

  final String label;
  final VoidCallback onTap;
  final String? semantics;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semantics ?? label,
        excludeSemantics: true,
        child: Container(
          decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(22), boxShadow: DS.shadows(Ink3D.whiteBtn)),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: DS.circular(22),
              child: Container(
                constraints: BoxConstraints(minHeight: DS.s(44)),
                padding: DS.sym(h: 16, v: 10),
                child: Center(widthFactor: 1, child: Text(label, style: Ink3D.text(13, FontWeight.w700, TaxiCal.accent, letterSpacing: 0))),
              ),
            ),
          ),
        ),
      );
}

class TaxiSmallOutline extends StatelessWidget {
  const TaxiSmallOutline({super.key, required this.label, required this.onTap, this.semantics});

  final String label;
  final VoidCallback? onTap;
  final String? semantics;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semantics ?? label,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: DS.circular(16),
          child: Container(
            constraints: BoxConstraints(minHeight: DS.s(32)),
            padding: DS.sym(h: 12, v: 6),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              borderRadius: DS.circular(16),
              border: Border.all(color: TaxiCal.ownDot, width: DS.s(1.2)),
            ),
            child: Center(widthFactor: 1, child: Text(label, maxLines: 1, style: Ink3D.text(12, FontWeight.w700, TaxiCal.accent, letterSpacing: 0))),
          ),
        ),
      );
}

class TaxiBottomActions extends StatelessWidget {
  const TaxiBottomActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.br(BorderRadius.vertical(top: Radius.circular(CardRadius.sheetValue))),
          boxShadow: DS.shadows(Ink3D.topEdge),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(12), DS.s(14), DS.s(14) + MediaQuery.paddingOf(context).bottom),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Gap.h(12),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      );
}

class TaxiMoneyTile extends StatelessWidget {
  const TaxiMoneyTile({super.key, required this.label, required this.value, this.valueColor, this.amber = false, this.onTap, this.semantics});

  final String label;
  final String value;
  final Color? valueColor;
  final bool amber;
  final VoidCallback? onTap;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: DS.sym(h: 10, v: 9),
      decoration: BoxDecoration(
        color: amber ? TaxiCal.amberFill : TaxiCal.softFill,
        borderRadius: DS.circular(12),
        border: amber ? Border.all(color: OwnerLook.taxi.lockLine, width: DS.s(1)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w600, amber ? TaxiCal.amber : Ink3D.grey, letterSpacing: 0)),
          Gap.v(2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1, style: Ink3D.text(15, FontWeight.w700, valueColor ?? (amber ? TaxiCal.amber : Ink3D.title), letterSpacing: 0)),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: semantics ?? '$label $value',
      excludeSemantics: true,
      child: onTap == null ? tile : InkWell(onTap: onTap, borderRadius: DS.circular(12), child: tile),
    );
  }
}

class TaxiMoneyTiles extends StatelessWidget {
  const TaxiMoneyTiles({super.key, required this.booked, required this.received, required this.toCollect, this.locked = false, this.onToCollect});

  final int booked;
  final int received;
  final int toCollect;
  final bool locked;
  final VoidCallback? onToCollect;

  @override
  Widget build(BuildContext context) {
    String v(int n) => locked ? TaxiCalendarStrings.hiddenAmount : Money.exact(n);
    final hint = locked ? Ink3D.hint : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: TaxiMoneyTile(label: TaxiCalendarStrings.booked, value: v(booked), valueColor: hint)),
        Gap.h(8),
        Expanded(child: TaxiMoneyTile(label: TaxiCalendarStrings.received, value: v(received), valueColor: hint ?? TaxiCal.greenText)),
        Gap.h(8),
        Expanded(
          child: TaxiMoneyTile(
            label: locked || onToCollect == null ? TaxiCalendarStrings.toCollect : TaxiCalendarStrings.toCollectOpen,
            value: v(toCollect),
            amber: !locked,
            valueColor: hint,
            onTap: locked ? null : onToCollect,
          ),
        ),
      ],
    );
  }
}

class TaxiMoneyCard extends StatelessWidget {
  const TaxiMoneyCard({
    super.key,
    required this.month,
    required this.locked,
    this.booked = 0,
    this.received = 0,
    this.toCollect = 0,
    this.onOpen,
    this.onToCollect,
    this.body,
  });

  final DateTime month;
  final bool locked;
  final int booked;
  final int received;
  final int toCollect;
  final VoidCallback? onOpen;
  final VoidCallback? onToCollect;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      key: locked ? GateKeys.softCard : null,
      padding: DS.all(14),
      decoration: TaxiCal.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Art3D(asset: ListingArt.moneyBag, size: 36),
              Gap.h(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(TaxiCalendarStrings.thisMonth, style: Ink3D.text(14.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
                    Text(locked ? TaxiCalendarStrings.bookedReceivedToCollect : TaxiCalendarStrings.monthOnlyYou(month),
                        maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                  ],
                ),
              ),
              if (locked) const SeePlusButton(taxi: true) else if (TaxiCal.isPlus) const TaxiBadge(kind: TaxiBadgeKind.plus),
            ],
          ),
          Gap.v(12),
          TaxiMoneyTiles(booked: booked, received: received, toCollect: toCollect, locked: locked, onToCollect: onToCollect),
          ?body,
          if (locked) ...[
            Gap.v(10),
            Text(TaxiCalendarStrings.lockedLine, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, height: 1.4, letterSpacing: 0)),
          ],
        ],
      ),
    );
    if (locked || onOpen == null) return card;
    return Semantics(
      button: true,
      child: InkWell(onTap: onOpen, borderRadius: DS.br(CardRadius.hero), child: card),
    );
  }
}

class TaxiMeterTile extends StatelessWidget {
  const TaxiMeterTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 12, v: 10),
        decoration: TaxiCal.card(hero: false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, maxLines: 1, style: Ink3D.text(15, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
          ],
        ),
      );
}

class TaxiMeterPair extends StatelessWidget {
  const TaxiMeterPair({super.key, required this.left, required this.right});

  final TaxiMeterTile left;
  final TaxiMeterTile right;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [Expanded(child: left), Gap.h(10), Expanded(child: right)],
        ),
      );
}
