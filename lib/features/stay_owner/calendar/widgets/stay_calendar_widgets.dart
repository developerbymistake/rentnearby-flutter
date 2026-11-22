import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../owner_core/calendar/models/calendar_models.dart';
import '../../../owner_core/look/owner_look.dart';
import '../../../owner_core/money/money_notes_fields.dart';
import '../../../owner_core/plan/gate_keys.dart';
import '../../../owner_core/plan/plan_gate.dart';
import '../../../owner_core/strings/owner_shared_strings.dart';
import '../../strings/stay_calendar_strings.dart';
import '../../widgets/stay_widgets.dart';

enum StayTileKind { app, own, blocked, cancelled }

abstract final class StayCalArt {
  static String rule(String? label) {
    if (label == null) return ListingArt.calendar;
    return label.toLowerCase().contains('diwali') ? ListingArt.diyaLamp : ListingArt.star;
  }
}

abstract final class StayCalKit {
  static final KitTone green = KitTone(
    accent: ListingTone.forest.g1,
    accentDark: ListingTone.forest.g2,
    tint: ListingTone.forest.tint,
    gradient: ListingTone.forest.gradient,
    glow: ListingTone.forest.g2,
  );
}

// Pushed calendar pages: below a short window (split screen, tablet landscape) the header drops
// its subtitle and the bottom bar scrolls as the last item of the body.
class StayCalScaffold extends StatelessWidget {
  const StayCalScaffold({super.key, required this.header, required this.body, this.bar, this.background});

  static double get shortBelow => DS.s(480);

  final Widget Function(bool compact) header;
  final Widget Function(BuildContext context, Widget? inlineBar) body;
  final Widget? bar;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background ?? OwnerLook.stay.page,
      body: LayoutBuilder(
        builder: (context, box) {
          final short = box.maxHeight < shortBelow;
          final b = bar;
          return Column(
            children: [
              header(short),
              Expanded(child: body(context, short ? b : null)),
              if (!short && b != null) b,
            ],
          );
        },
      ),
    );
  }
}

class StayCalHeader extends StatelessWidget {
  const StayCalHeader({super.key, required this.title, this.subtitle, this.trailing, this.onBack, this.compact = false});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    final sub = compact ? null : subtitle;
    return Container(
      decoration: BoxDecoration(
        gradient: ListingTone.forest.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(DS.radius(4))),
        boxShadow: ListingTone.forest.glow(),
      ),
      padding: EdgeInsets.fromLTRB(DS.s(12), MediaQuery.viewPaddingOf(context).top + DS.s(compact ? 6 : 14), DS.s(12), DS.s(compact ? 6 : 14)),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: MaterialLocalizations.of(context).backButtonTooltip,
            excludeSemantics: true,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack ?? () => Navigator.maybePop(context),
              child: Container(
                width: DS.s(40),
                height: DS.s(40),
                decoration: BoxDecoration(color: white.withValues(alpha: Alpha.v22), shape: BoxShape.circle),
                child: Icon(Icons.chevron_left_rounded, size: DS.s(24), color: white),
              ),
            ),
          ),
          Gap.h(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(header: true, child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w800, white, letterSpacing: 0))),
                if (sub != null && sub.isNotEmpty)
                  Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w600, white.withValues(alpha: Alpha.v90), letterSpacing: 0)),
              ],
            ),
          ),
          if (trailing != null) ...[Gap.h(8), trailing!],
        ],
      ),
    );
  }
}

class StayPlusTag extends StatelessWidget {
  const StayPlusTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 9, v: 3),
        decoration: BoxDecoration(color: StayLook.indigoSoft, borderRadius: DS.circular(10)),
        child: Text(OwnerSharedStrings.plus, style: Ink3D.text(11, FontWeight.w700, StayLook.indigoText, letterSpacing: 0)),
      );
}

class StayHeaderPills extends StatelessWidget {
  const StayHeaderPills({super.key, this.plus = false, this.onPast});

  final bool plus;
  final VoidCallback? onPast;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (plus) const StayPlusTag(),
          if (plus && onPast != null) Gap.h(8),
          if (onPast != null)
            Semantics(
              label: StayCalendarStrings.pastBookings,
              button: true,
              excludeSemantics: true,
              child: StayWhitePill(label: StayCalendarStrings.past, color: StayLook.indigoText, onTap: onPast),
            ),
        ],
      );
}

abstract final class StayTileLook {
  static (Color, Color) colors(StayTileKind k) => switch (k) {
        StayTileKind.app => (StayLook.greenSoft, StayLook.greenText),
        StayTileKind.own => (StayLook.indigoSoft, StayLook.indigoText),
        StayTileKind.blocked => (OwnerLook.greySoft, Ink3D.sub),
        StayTileKind.cancelled => (OwnerLook.greySoft, Ink3D.hint),
      };

  static StayTileKind of(CalendarEntry e) => e.cancelled ? StayTileKind.cancelled : (e.isAuto ? StayTileKind.app : StayTileKind.own);
}

class StayDateTile extends StatelessWidget {
  const StayDateTile({super.key, required this.top, required this.bottom, required this.kind});

  final String top;
  final String bottom;
  final StayTileKind kind;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = StayTileLook.colors(kind);
    return ExcludeSemantics(
      child: Container(
        width: DS.s(44),
        padding: DS.sym(v: 6),
        decoration: BoxDecoration(color: bg, borderRadius: DS.circular(10)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(top, maxLines: 1, style: Ink3D.text(16, FontWeight.w800, fg, letterSpacing: 0)),
            Text(bottom, maxLines: 1, style: Ink3D.text(9, FontWeight.w800, fg, letterSpacing: 0.4)),
          ],
        ),
      ),
    );
  }
}

class StayKindChip extends StatelessWidget {
  const StayKindChip({super.key, required this.label, required this.kind});

  final String label;
  final StayTileKind kind;

  static Widget of(CalendarEntry e) =>
      StayKindChip(label: e.isAuto ? StayCalendarStrings.fromApp : StayCalendarStrings.addedByYou, kind: e.isAuto ? StayTileKind.app : StayTileKind.own);

  static const Widget blocked = StayKindChip(label: StayCalendarStrings.legendBlocked, kind: StayTileKind.blocked);
  static const Widget cancelled = StayKindChip(label: StayCalendarStrings.cancelled, kind: StayTileKind.cancelled);

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = StayTileLook.colors(kind);
    return Container(
      padding: DS.sym(h: 8, v: 3),
      decoration: BoxDecoration(color: bg, borderRadius: DS.circular(10)),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w700, fg, letterSpacing: 0)),
    );
  }
}

class StaySoftChip extends StatelessWidget {
  const StaySoftChip({super.key, required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 8, v: 3),
        decoration: BoxDecoration(color: bg, borderRadius: DS.circular(10)),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w700, fg, letterSpacing: 0)),
      );
}

class StayEntryRow extends StatelessWidget {
  const StayEntryRow({
    super.key,
    required this.tileTop,
    required this.tileBottom,
    required this.kind,
    required this.title,
    this.sub,
    this.chips = const [],
    this.trailing,
    this.onTap,
    this.semantics,
    this.dim = false,
  });

  final String tileTop;
  final String tileBottom;
  final StayTileKind kind;
  final String title;
  final String? sub;
  final List<Widget> chips;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semantics;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: DS.sym(h: 14, v: 12),
      child: Row(
        children: [
          StayDateTile(top: tileTop, bottom: tileBottom, kind: kind),
          Gap.h(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w700, dim ? Ink3D.grey : Ink3D.title, letterSpacing: 0)),
                if (sub != null && sub!.isNotEmpty)
                  Text(sub!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
                if (chips.isNotEmpty) ...[
                  Gap.v(4),
                  Wrap(spacing: DS.gh(6), runSpacing: DS.gv(4), children: chips),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[Gap.h(8), Flexible(flex: 0, child: trailing!)],
        ],
      ),
    );
    final tappable = onTap == null ? body : InkWell(onTap: onTap, child: body);
    return Semantics(
      button: onTap != null,
      label: semantics,
      child: Opacity(opacity: dim ? Alpha.v72 : Alpha.full, child: tappable),
    );
  }
}

class StayCardSegment extends StatelessWidget {
  const StayCardSegment({super.key, required this.child, required this.first, required this.last, this.margin});

  final Widget child;
  final bool first;
  final bool last;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final r = DS.radius(16);
    final big = DS.radius(34);
    return Container(
      margin: margin ?? DS.insets(l: 18, r: 18),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: first ? Radius.circular(r) : Radius.zero,
          topRight: first ? Radius.circular(big) : Radius.zero,
          bottomLeft: last ? Radius.circular(r) : Radius.zero,
          bottomRight: last ? Radius.circular(r) : Radius.zero,
        ),
        boxShadow: DS.shadows(ShadowTokens.elev1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!first) Divider(height: DS.s(1), thickness: DS.s(1), color: StayLook.rowLine),
          child,
        ],
      ),
    );
  }
}

class StayGroupHeader extends StatelessWidget {
  const StayGroupHeader({super.key, required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: DS.insets(l: 22, t: 16, r: 22, b: 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: Ink3D.text(11, FontWeight.w800, Ink3D.grey, letterSpacing: 0.6))),
            if (count != null) Text('$count', style: Ink3D.text(11, FontWeight.w800, Ink3D.title, letterSpacing: 0)),
          ],
        ),
      );
}

class StayKv extends StatelessWidget {
  const StayKv({super.key, required this.label, required this.value, this.trailing, this.divider = true, this.bold = true});

  final String label;
  final String value;
  final Widget? trailing;
  final bool divider;
  final bool bold;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(v: 10),
        decoration: divider ? BoxDecoration(border: Border(top: BorderSide(color: StayLook.rowLine, width: DS.s(1)))) : null,
        child: Row(
          children: [
            Text(label, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
            Gap.h(12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing ??
                    Text(value,
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Ink3D.text(12, bold ? FontWeight.w700 : FontWeight.w500, Ink3D.title, letterSpacing: 0)),
              ),
            ),
          ],
        ),
      );
}

class StayNote extends StatelessWidget {
  const StayNote({super.key, required this.text, this.art = ListingArt.shield, this.margin});

  final String text;
  final String art;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin ?? DS.insets(l: 18, t: 14, r: 18),
        padding: DS.sym(h: 14, v: 12),
        decoration: BoxDecoration(color: StayLook.tealSoft, borderRadius: DS.circular(14)),
        child: Row(
          children: [
            ExcludeSemantics(child: Art3D(asset: art, size: 30)),
            Gap.h(10),
            Expanded(child: Text(text, style: Ink3D.text(11.5, FontWeight.w600, StayLook.tealDeep.text, height: 1.4, letterSpacing: 0))),
          ],
        ),
      );
}

class StaySmallLine extends StatelessWidget {
  const StaySmallLine({super.key, required this.text, this.art, this.margin});

  final String text;
  final String? art;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin ?? DS.insets(l: 22, t: 10, r: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (art != null) ...[ExcludeSemantics(child: Art3D(asset: art!, size: 14)), Gap.h(6)],
            Expanded(child: Text(text, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, height: 1.4, letterSpacing: 0))),
          ],
        ),
      );
}

class StayCalBar extends StatelessWidget {
  const StayCalBar({super.key, required this.primary, this.secondary, this.onPrimary, this.onSecondary, this.secondaryDanger = false});

  final String primary;
  final String? secondary;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final bool secondaryDanger;

  @override
  Widget build(BuildContext context) {
    final second = secondary;
    return Container(
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(22))),
        boxShadow: DS.shadows(Ink3D.topEdge),
      ),
      padding: EdgeInsets.fromLTRB(DS.s(14), DS.s(10), DS.s(14), MediaQuery.viewPaddingOf(context).bottom + DS.s(12)),
      child: Row(
        children: [
          Expanded(child: PrimaryButton(label: primary, tone: StayCalKit.green, compact: true, onPressed: onPrimary)),
          if (second != null) ...[
            Gap.h(10),
            Expanded(
              child: StayPill(
                label: second,
                kind: secondaryDanger ? StayPillKind.danger : StayPillKind.outline,
                expand: true,
                onTap: onSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StayMeterTiles extends StatelessWidget {
  const StayMeterTiles({super.key, required this.entries, required this.blocks});

  final Meter? entries;
  final Meter? blocks;

  @override
  Widget build(BuildContext context) {
    final off = !PlanGate.paymentOn;
    final tiles = <Widget>[];
    final e = entries;
    final b = blocks;
    if (e != null) {
      tiles.add(_tile(off ? StayCalendarStrings.bookingsAddedOff(e.used) : StayCalendarStrings.meterCount(e.used, e.limit), off ? null : StayCalendarStrings.bookingsYouAdded));
    }
    if (b != null) {
      tiles.add(_tile(
        off ? StayCalendarStrings.blocksOff(b.used) : StayCalendarStrings.meterCount(b.used, b.limit),
        off ? null : (b.limit == 1 ? StayCalendarStrings.blockedRange : StayCalendarStrings.blockedRanges),
      ));
    }
    if (tiles.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: DS.insets(l: 18, t: 14, r: 18),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[if (i > 0) Gap.h(10), Expanded(child: tiles[i])],
          ],
        ),
      ),
    );
  }

  Widget _tile(String big, String? label) => Container(
        padding: DS.sym(h: 12, v: 10),
        decoration: BoxDecoration(color: DesignColors.surface, borderRadius: StayLook.cardRadius(22), boxShadow: DS.shadows(ShadowTokens.elev1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(big, maxLines: 2, style: Ink3D.text(14, FontWeight.w800, Ink3D.title, letterSpacing: 0)),
            if (label != null) Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
          ],
        ),
      );
}

class StayAmberRow extends StatelessWidget {
  const StayAmberRow({super.key, required this.text, this.onSeePlus, this.margin});

  final String text;
  final VoidCallback? onSeePlus;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    if (!PlanGate.canUpgrade) return const SizedBox.shrink();
    return Container(
      key: GateKeys.softRow,
      margin: margin,
      padding: DS.sym(h: 14, v: 10),
      decoration: BoxDecoration(color: StayLook.amberSoft, borderRadius: DS.circular(14)),
      child: Row(
        children: [
          ExcludeSemantics(child: Art3D(asset: ListingArt.locked, size: 22)),
          Gap.h(10),
          Expanded(child: Text(text, style: Ink3D.text(11.5, FontWeight.w700, StayLook.amberText, height: 1.35, letterSpacing: 0))),
          Gap.h(8),
          KeyedSubtree(
            key: GateKeys.seePlus,
            child: StayPill(label: OwnerSharedStrings.seePlus, kind: StayPillKind.indigo, onTap: onSeePlus ?? PlanGate.seePlus),
          ),
        ],
      ),
    );
  }
}

class StayChipFor extends StatelessWidget {
  const StayChipFor({super.key, required this.entry});

  final CalendarEntry entry;

  @override
  Widget build(BuildContext context) => BalanceChip(chip: entry.chip, amount: entry.chipAmount);
}
