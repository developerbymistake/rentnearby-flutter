import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/money_format.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/pricing/special_price_math.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../calendar/models/stay_calendar_models.dart';
import '../calendar/stay_entry_sheet.dart';
import '../calendar/widgets/stay_calendar_widgets.dart';
import '../strings/stay_gate_strings_calendar.dart';
import '../strings/stay_special_price_strings.dart';
import '../widgets/stay_widgets.dart';
import 'stay_special_prices_controller.dart';

abstract final class SpecialPriceRules {
  static const int step = 5;
  static const int min = 5;
  static const int lowerMax = 50;
  static const int higherMax = 100;
  static const int maxNights = 60;
  static const int startDays = 180;

  static int maxFor(bool lower) => lower ? lowerMax : higherMax;

  static int clamp(int p, bool lower) => p < min ? min : (p > maxFor(lower) ? maxFor(lower) : p);

  static int nights(DateTime from, DateTime to) => OwnerDates.daysBetween(from, to) + 1;

  static String? datesError(DateTime from, DateTime to, DateTime today) {
    if (from.isAfter(OwnerDates.addDays(today, startDays))) return StaySpecialPriceStrings.startTooFar;
    if (nights(from, to) > maxNights) return StaySpecialPriceStrings.tooManyNights;
    return null;
  }
}

abstract final class StaySpecialPriceSheet {
  static Future<void> open(
    BuildContext context,
    StaySpecialPricesController c, {
    SpecialPriceBand? rule,
    DateTime? from,
    DateTime? to,
    String? festivalId,
  }) async {
    if (rule == null && c.needsG12) {
      await PlanGate.showLimit(context, StayGateStringsCalendar.g12(endsOn: c.soonestEnd));
      return;
    }
    if (!context.mounted) return;
    final next = await SheetFrame.show<SpecialPriceBand>(
      context,
      isDismissible: false,
      builder: (_) => StaySpecialPriceForm(controller: c, rule: rule, from: from, to: to, festivalId: festivalId),
    );
    if (next != null && context.mounted) await open(context, c, rule: next);
  }
}

class StaySpecialPriceForm extends StatefulWidget {
  const StaySpecialPriceForm({super.key, required this.controller, this.rule, this.from, this.to, this.festivalId});

  final StaySpecialPricesController controller;
  final SpecialPriceBand? rule;
  final DateTime? from;
  final DateTime? to;
  final String? festivalId;

  @override
  State<StaySpecialPriceForm> createState() => StaySpecialPriceFormState();
}

class StaySpecialPriceFormState extends State<StaySpecialPriceForm> {
  late String id;
  String? festivalId;
  bool picking = false;
  DateTime? from;
  DateTime? to;
  bool lower = false;
  int percent = 20;
  String? serverLine;
  SpecialPriceOverlapInfo? overlap;
  DateTime? _overlapFrom;
  DateTime? _overlapTo;
  bool savesOut = false;
  late final _Initial _initial;

  StaySpecialPricesController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    id = r?.id ?? StayIds.next();
    if (r != null) {
      from = r.dateFrom;
      to = r.dateTo;
      lower = r.direction == PriceDirection.lower;
      percent = SpecialPriceRules.clamp(r.percent <= 0 ? 20 : r.percent, lower);
      final f = _festivalFor(from, to);
      festivalId = f?.id;
      picking = f == null;
    } else {
      final fest = widget.festivalId == null ? null : _festivalById(widget.festivalId);
      from = fest?.dateFrom ?? widget.from;
      to = fest?.dateTo ?? widget.to;
      festivalId = fest?.id ?? _festivalFor(from, to)?.id;
      picking = festivalId == null && from != null;
      percent = StaySpecialPriceMemory.lastPercent ?? 20;
    }
    savesOut = (c.page?.savesLeftToday ?? 1) <= 0;
    _initial = _Initial(from, to, lower, percent);
  }

  FestivalRow? _festivalById(String? id) {
    for (final f in c.festivals) {
      if (f.id == id) return f;
    }
    return null;
  }

  FestivalRow? _festivalFor(DateTime? a, DateTime? b) {
    if (a == null || b == null) return null;
    for (final f in c.festivals) {
      final fa = f.dateFrom;
      final fb = f.dateTo;
      if (fa != null && fb != null && OwnerDates.sameDay(fa, a) && OwnerDates.sameDay(fb, b)) return f;
    }
    return null;
  }

  bool get dirty => from != _initial.from || to != _initial.to || lower != _initial.lower || percent != _initial.percent;

  bool get _overlapStill {
    final a = _overlapFrom;
    final b = _overlapTo;
    final f = from;
    final t = to;
    return overlap != null && a != null && b != null && f != null && t != null && OwnerDates.sameDay(a, f) && OwnerDates.sameDay(b, t);
  }

  String? get datesError {
    final f = from;
    final t = to;
    if (f == null || t == null) return null;
    return SpecialPriceRules.datesError(f, t, c.today);
  }

  bool get canSave {
    final f = from;
    final t = to;
    if (f == null || t == null || t.isBefore(f)) return false;
    if (savesOut || _overlapStill || datesError != null) return false;
    return c.page?.rooms.isNotEmpty ?? false;
  }

  void _pickFestival(FestivalRow f) => setState(() {
        festivalId = f.id;
        picking = false;
        from = f.dateFrom;
        to = f.dateTo;
        serverLine = null;
      });

  Future<void> _pickDate(bool isFrom) async {
    final today = c.today;
    final first = isFrom ? today : (from ?? today);
    final last = isFrom ? OwnerDates.addDays(today, SpecialPriceRules.startDays + 30) : OwnerDates.addDays(from ?? today, SpecialPriceRules.maxNights + 30);
    final current = (isFrom ? from : to) ?? first;
    final picked = await TemplateCalendarPopup.pickDate(
      context,
      initial: current.isBefore(first) ? first : (current.isAfter(last) ? last : current),
      first: first,
      last: last,
      label: isFrom ? StaySpecialPriceStrings.from : StaySpecialPriceStrings.to,
      tone: StayCalKit.green,
    );
    if (picked == null || !mounted) return;
    setState(() {
      serverLine = null;
      final p = OwnerDates.only(picked);
      if (isFrom) {
        from = p;
        final t = to;
        if (t == null || t.isBefore(p)) to = p;
      } else {
        to = p;
      }
    });
  }

  void _direction(bool l) => setState(() {
        lower = l;
        percent = SpecialPriceRules.clamp(percent, l);
      });

  void _step(int delta) => setState(() => percent = SpecialPriceRules.clamp(percent + delta, lower));

  Future<void> _save() async {
    final f = from;
    final t = to;
    if (f == null || t == null || !canSave) return;
    final fest = festivalId;
    final draft = StaySpecialPriceDraft(
      id: id,
      dateFrom: f,
      dateTo: t,
      lower: lower,
      percent: percent,
      festivalDateId: fest != null && !picking ? fest : null,
      version: widget.rule?.version,
    );
    final r = await c.save(draft, edit: widget.rule != null);
    if (!mounted) return;
    switch (r) {
      case OwnerOk():
        Navigator.of(context).pop();
      case OwnerOffline():
      case OwnerFailed():
        AppToast.error(OwnerSharedStrings.noConnection);
      case OwnerRefused():
        if (r.rateLimited) {
          AppToast.info(OwnerSharedStrings.tooManyTries);
          return;
        }
        if (await PlanGate.handleRefusal(context, r, StayGateStringsCalendar.fromRefusal)) return;
        if (!mounted) return;
        setState(() {
          switch (r.type) {
            case OwnerErrorTypes.specialPriceOverlap:
              overlap = SpecialPriceOverlapInfo.maybe(r.data) ?? SpecialPriceOverlapInfo(id: '', label: StaySpecialPriceStrings.yourDates);
              _overlapFrom = f;
              _overlapTo = t;
              serverLine = null;
            case OwnerErrorTypes.specialPriceSavesLimit:
              savesOut = true;
              serverLine = StaySpecialPriceStrings.savesLimit;
            case OwnerErrorTypes.specialPriceInvalid:
              serverLine = _invalidLine(r.message);
            case OwnerErrorTypes.staleEdit:
              serverLine = OwnerSharedStrings.staleEdit;
              c.fetch();
            default:
              serverLine = r.message ?? OwnerSharedStrings.noConnection;
          }
        });
    }
  }

  String _invalidLine(String? message) {
    final m = (message ?? '').toLowerCase();
    if (m.contains('60')) return StaySpecialPriceStrings.tooManyNights;
    if (m.contains('180')) return StaySpecialPriceStrings.startTooFar;
    if (m.contains('percent')) return lower ? StaySpecialPriceStrings.percentLowerRange : StaySpecialPriceStrings.percentHigherRange;
    return message ?? StaySpecialPriceStrings.tooManyNights;
  }

  Future<void> _close() async {
    final nav = Navigator.of(context);
    if (!dirty) {
      nav.pop();
      return;
    }
    if (await OwnerConfirm.discard(context) && nav.mounted) nav.pop();
  }

  SpecialPriceBand? _ruleById(String id) {
    for (final r in c.rules) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final rooms = c.page?.rooms ?? const <StayPriceRoom>[];
    final ov = _overlapStill ? overlap : null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: SheetFrame(
        tone: ListingTone.forest,
        title: StaySpecialPriceStrings.sheetTitle,
        subtitle: StaySpecialPriceStrings.sheetSub(c.listingName),
        size: SheetSize.form,
        footer: SingleFlightButton(
          onPressed: canSave ? _save : null,
          builder: (ctx, onPressed, busy) => PrimaryButton(label: StaySpecialPriceStrings.save, tone: StayCalKit.green, loading: busy, onPressed: onPressed),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(StaySpecialPriceStrings.dates),
            Wrap(
              spacing: DS.gh(8),
              runSpacing: DS.gv(8),
              children: [
                for (final f in c.festivals)
                  _chip(
                    StaySpecialPriceStrings.festivalChip(f.name, StaySpecialPriceStrings.rangeTo(f.dateFrom ?? c.today, f.dateTo ?? c.today)),
                    on: !picking && festivalId == f.id,
                    art: f.name.toLowerCase().contains('diwali') ? ListingArt.diyaLamp : ListingArt.star,
                    onTap: () => _pickFestival(f),
                  ),
                _chip(StaySpecialPriceStrings.pickDates, on: picking, art: ListingArt.calendar, onTap: () => setState(() {
                      picking = true;
                      festivalId = null;
                      from ??= c.today;
                      to ??= from;
                    })),
              ],
            ),
            if (picking) ...[
              Row(children: [
                Expanded(child: StayDateBox(label: StaySpecialPriceStrings.from, date: from ?? c.today, red: ov != null, onTap: () => _pickDate(true))),
                Gap.h(8),
                Expanded(child: StayDateBox(label: StaySpecialPriceStrings.to, date: to ?? from ?? c.today, red: ov != null, onTap: () => _pickDate(false))),
              ]),
            ],
            if (ov != null) ...[
              Gap.v(10),
              const StayRedBox(text: StaySpecialPriceStrings.overlap),
              Padding(
                padding: DS.insets(t: 8, b: 8),
                child: Text(
                  StaySpecialPriceStrings.overlapLine(ov.label, ov.dateFrom == null || ov.dateTo == null ? '' : StaySpecialPriceStrings.rangeTo(ov.dateFrom ?? c.today, ov.dateTo ?? c.today)),
                  style: Ink3D.text(10.5, FontWeight.w500, Ink3D.sub, height: 1.4, letterSpacing: 0),
                ),
              ),
              StayPill(
                label: StaySpecialPriceStrings.editRule(ov.label),
                kind: StayPillKind.outline,
                expand: true,
                onTap: () {
                  final target = _ruleById(ov.id);
                  Navigator.of(context).pop(target);
                },
              ),
            ],
            if (datesError != null) _error(datesError ?? ''),
            _label(StaySpecialPriceStrings.change),
            Row(children: [
              Expanded(child: _segment(StaySpecialPriceStrings.lowerPrice, lower, () => _direction(true))),
              Gap.h(8),
              Expanded(child: _segment(StaySpecialPriceStrings.higherPrice, !lower, () => _direction(false))),
            ]),
            Gap.v(10),
            Row(
              children: [
                Expanded(
                  child: Wrap(spacing: DS.gh(6), runSpacing: DS.gv(6), children: [
                    for (final p in StaySpecialPriceStrings.percentChips)
                      if (p <= SpecialPriceRules.maxFor(lower)) _percentChip(p),
                  ]),
                ),
                _stepper(),
              ],
            ),
            if (from != null && to != null && rooms.isNotEmpty && ov == null) _preview(rooms),
            if (ov == null) ...[
              Gap.v(8),
              Text(StaySpecialPriceStrings.appliesNote, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
            ],
            if (serverLine != null) _error(serverLine ?? ''),
            Gap.v(8),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: DS.insets(t: 12, b: 6),
        child: Text(text, style: Ink3D.text(11.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
      );

  Widget _error(String text) => Padding(
        padding: DS.insets(t: 6),
        child: Semantics(liveRegion: true, child: Text(text, style: Ink3D.text(10.5, FontWeight.w600, DesignColors.error, letterSpacing: 0))),
      );

  Widget _chip(String label, {required bool on, required String art, required VoidCallback onTap}) => Semantics(
        button: true,
        selected: on,
        label: label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: DS.circular(20),
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: DS.s(40)),
            padding: DS.sym(h: 12, v: 8),
            decoration: BoxDecoration(
              gradient: on ? ListingTone.forest.gradient : null,
              color: on ? null : DesignColors.surface,
              borderRadius: DS.circular(20),
              border: on ? null : Border.all(color: DesignColors.border, width: DS.s(1)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ExcludeSemantics(child: Art3D(asset: art, size: 18)),
              Gap.h(6),
              Flexible(child: Text(label, style: Ink3D.text(11, FontWeight.w700, on ? DesignColors.onPrimary : Ink3D.title, letterSpacing: 0))),
            ]),
          ),
        ),
      );

  Widget _segment(String label, bool on, VoidCallback onTap) => Semantics(
        button: true,
        selected: on,
        child: InkWell(
          borderRadius: DS.circular(12),
          onTap: onTap,
          child: Container(
            height: DS.s(44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: on ? ListingTone.indigo.gradient : null,
              color: on ? null : DesignColors.surface,
              borderRadius: DS.circular(12),
              border: on ? null : Border.all(color: DesignColors.border, width: DS.s(1)),
            ),
            child: Text(label, style: Ink3D.text(12, FontWeight.w700, on ? DesignColors.onPrimary : StayLook.indigoText, letterSpacing: 0)),
          ),
        ),
      );

  Widget _percentChip(int p) {
    final on = percent == p;
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() => percent = p),
        child: Container(
          width: DS.s(44),
          height: DS.s(44),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: on ? ListingTone.indigo.gradient : null,
            color: on ? null : DesignColors.surface,
            border: on ? null : Border.all(color: DesignColors.border, width: DS.s(1)),
          ),
          child: Text(StaySpecialPriceStrings.percent(p), style: Ink3D.text(11, FontWeight.w700, on ? DesignColors.onPrimary : Ink3D.title, letterSpacing: 0)),
        ),
      ),
    );
  }

  Widget _stepper() {
    Widget btn(String t, String a11y, VoidCallback? onTap) => Semantics(
          button: true,
          label: a11y,
          excludeSemantics: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: DS.s(32),
              height: DS.s(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: onTap == null ? StayLook.rowLine : StayLook.indigoSoft),
              child: Text(t, style: Ink3D.text(14, FontWeight.w800, StayLook.indigoText, letterSpacing: 0)),
            ),
          ),
        );
    return Container(
      padding: DS.sym(h: 4, v: 4),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(22), border: Border.all(color: DesignColors.border, width: DS.s(1))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(StaySpecialPriceStrings.minus, StaySpecialPriceStrings.decrease, percent > SpecialPriceRules.min ? () => _step(-SpecialPriceRules.step) : null),
        Padding(padding: DS.sym(h: 8), child: Text(StaySpecialPriceStrings.percent(percent), style: Ink3D.text(12, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
        btn(StaySpecialPriceStrings.plusSign, StaySpecialPriceStrings.increase, percent < SpecialPriceRules.maxFor(lower) ? () => _step(SpecialPriceRules.step) : null),
      ]),
    );
  }

  Widget _preview(List<StayPriceRoom> rooms) {
    final f = from ?? c.today;
    final t = to ?? f;
    final n = SpecialPriceRules.nights(f, t);
    final range = StaySpecialPriceStrings.rangeTo(f, t);
    final head = lower ? StaySpecialPriceStrings.previewLower(range, n, percent) : StaySpecialPriceStrings.previewHigher(range, n);
    return Container(
      margin: DS.insets(t: 12),
      padding: DS.sym(h: 12, v: 10),
      decoration: BoxDecoration(color: StayLook.greenSoft, borderRadius: DS.circular(12), border: Border.all(color: ListingTone.forest.tint, width: DS.s(1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(head, style: Ink3D.text(10.5, FontWeight.w700, StayLook.greenText, letterSpacing: 0)),
          for (final room in rooms.take(8))
            Container(
              padding: DS.sym(v: 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: ListingTone.forest.tint, width: DS.s(1)))),
              child: Row(children: [
                Expanded(child: Text(room.roomName, style: Ink3D.text(11.5, FontWeight.w500, Ink3D.title, letterSpacing: 0))),
                Text(Money.exact(room.basePrice),
                    style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0).copyWith(decoration: TextDecoration.lineThrough)),
                Gap.h(8),
                Text(Money.exact(SpecialPriceMath.adjust(room.basePrice, lower, percent)), style: Ink3D.text(13, FontWeight.w800, Ink3D.title, letterSpacing: 0)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _Initial {
  const _Initial(this.from, this.to, this.lower, this.percent);
  final DateTime? from;
  final DateTime? to;
  final bool lower;
  final int percent;
}
