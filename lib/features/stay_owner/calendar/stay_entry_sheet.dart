import 'dart:math';

import 'package:flutter/material.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../owner_core/calendar/calendar_api.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../owner_core/look/owner_look.dart';
import '../../owner_core/money/money_notes_fields.dart';
import '../../owner_core/money/phone_guard.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/sheets/owner_confirm.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../strings/stay_calendar_strings.dart';
import '../strings/stay_gate_strings_calendar.dart';
import '../widgets/stay_widgets.dart';
import 'models/stay_calendar_models.dart';
import 'stay_calendar_controller.dart';
import 'widgets/stay_calendar_widgets.dart';

abstract final class StayIds {
  static final Random _r = Random.secure();

  static String next() {
    String hex(int n) => List.generate(n, (_) => _r.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + _r.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }
}

abstract final class StayEntryRules {
  static const int labelMax = 60;
  static const int noteMax = 200;
  static const int maxNights = 60;
  static const int blockMaxNights = 90;
  static const int blockStartDays = 180;

  static int nights(DateTime from, DateTime to) => OwnerDates.daysBetween(from, to);

  static bool nightsOk(DateTime from, DateTime to) {
    final n = nights(from, to);
    return n >= 1 && n <= maxNights;
  }

  static bool blockOk(DateTime from, DateTime to, DateTime today) {
    final n = OwnerDates.daysBetween(from, to) + 1;
    if (n < 1 || n > blockMaxNights) return false;
    if (from.isBefore(today)) return false;
    return !from.isAfter(OwnerDates.addDays(today, blockStartDays));
  }
}

abstract final class StayEntrySheet {
  static Future<void> add(BuildContext context, StayCalendarController c, {DateTime? from, DateTime? to}) {
    final f = from ?? c.today;
    return _open(context, c, block: false, from: f, to: to ?? OwnerDates.addDays(f, 1));
  }

  static Future<void> edit(BuildContext context, StayCalendarController c, CalendarEntry e) =>
      _open(context, c, block: false, entry: e, from: e.dateFrom ?? c.today, to: e.dateTo ?? OwnerDates.addDays(e.dateFrom ?? c.today, 1));

  static Future<void> block(BuildContext context, StayCalendarController c, {DateTime? day}) async {
    if (c.needsG11) {
      await PlanGate.showLimit(context, StayGateStringsCalendar.g11());
      return;
    }
    if (!context.mounted) return;
    final d = day ?? c.today;
    await _open(context, c, block: true, from: d, to: d);
  }

  static Future<void> editBlock(BuildContext context, StayCalendarController c, CalendarBlock b) =>
      _open(context, c, block: true, existingBlock: b, from: b.dateFrom ?? c.today, to: b.dateTo ?? c.today);

  static Future<void> _open(
    BuildContext context,
    StayCalendarController c, {
    required bool block,
    required DateTime from,
    required DateTime to,
    CalendarEntry? entry,
    CalendarBlock? existingBlock,
  }) {
    return SheetFrame.show<void>(
      context,
      isDismissible: false,
      builder: (ctx) => StayEntryForm(
        controller: c,
        startBlock: block,
        from: from,
        to: to,
        entry: entry,
        existingBlock: existingBlock,
      ),
    );
  }
}

class StayEntryForm extends StatefulWidget {
  const StayEntryForm({
    super.key,
    required this.controller,
    required this.startBlock,
    required this.from,
    required this.to,
    this.entry,
    this.existingBlock,
  });

  final StayCalendarController controller;
  final bool startBlock;
  final DateTime from;
  final DateTime to;
  final CalendarEntry? entry;
  final CalendarBlock? existingBlock;

  @override
  State<StayEntryForm> createState() => StayEntryFormState();
}

enum StayBlockError { none, overlap, invalid }

class StayEntryFormState extends State<StayEntryForm> {
  late final TextEditingController label;
  late final TextEditingController note;
  late final MoneyNotesController money;
  late bool blockMode;
  late DateTime from;
  late DateTime to;
  late final String bookingId;
  late final String blockId;
  bool triedSave = false;
  String? serverLine;
  StayBlockError blockError = StayBlockError.none;
  DateTime? _errorFrom;
  DateTime? _errorTo;

  StayCalendarController get c => widget.controller;
  bool get editing => widget.entry != null || widget.existingBlock != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final b = widget.existingBlock;
    blockMode = widget.startBlock;
    label = TextEditingController(text: e?.label ?? b?.reason ?? '');
    note = TextEditingController(text: e?.note ?? '');
    money = MoneyNotesController(finalAmount: e?.finalAmount, receivedSoFar: e?.receivedSoFar, paidInFull: e?.paidInFull ?? false);
    from = OwnerDates.only(widget.from);
    to = OwnerDates.only(widget.to);
    bookingId = e?.id ?? StayIds.next();
    blockId = b?.id ?? StayIds.next();
    label.addListener(_changed);
    note.addListener(_changed);
    money.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    label.dispose();
    note.dispose();
    money.dispose();
    super.dispose();
  }

  bool get dirty {
    final e = widget.entry;
    final b = widget.existingBlock;
    if (e != null || b != null) {
      return label.text != (e?.label ?? b?.reason ?? '') ||
          note.text != (e?.note ?? '') ||
          !OwnerDates.sameDay(from, widget.from) ||
          !OwnerDates.sameDay(to, widget.to) ||
          money.finalAmount != e?.finalAmount ||
          money.receivedSoFar != e?.receivedSoFar ||
          money.paidInFull != (e?.paidInFull ?? false);
    }
    return label.text.isNotEmpty || note.text.isNotEmpty || money.dirtyFromEmpty;
  }

  bool get labelPhone => PhoneGuard.hasPhone(label.text);
  bool get notePhone => PhoneGuard.hasPhone(note.text);
  bool get labelEmpty => label.text.trim().isEmpty;
  bool get datesChangedSinceError {
    final f = _errorFrom;
    final t = _errorTo;
    if (f == null || t == null) return true;
    return !OwnerDates.sameDay(f, from) || !OwnerDates.sameDay(t, to);
  }

  bool get canSave {
    if (blockMode) {
      if (labelPhone) return false;
      if (blockError != StayBlockError.none && !datesChangedSinceError) return false;
      return !to.isBefore(from);
    }
    if (labelPhone || notePhone || money.error != null) return false;
    return StayEntryRules.nightsOk(from, to);
  }

  int get overlapBookings => blockMode ? 0 : c.overlapCount(from, to, exceptId: widget.entry?.id);
  bool get overlapBlocked => !blockMode && c.blockedBetween(from, to);

  DateTime get _first => blockMode ? c.today : (c.window.manualFrom ?? OwnerDates.addDays(c.today, -7));
  DateTime get _last {
    if (blockMode) return OwnerDates.addDays(c.today, StayEntryRules.blockStartDays + StayEntryRules.blockMaxNights);
    final m = c.window.manualTo;
    if (m != null) return m;
    final a = OwnerDates.addDays(c.today, 15);
    final b = OwnerDates.lastOfMonth(c.today);
    return a.isAfter(b) ? a : b;
  }

  Future<void> _pick(bool isFrom) async {
    final first = _first;
    final last = _last;
    final initial = isFrom ? from : to;
    final picked = await TemplateCalendarPopup.pickDate(
      context,
      initial: initial.isBefore(first) ? first : (initial.isAfter(last) ? last : initial),
      first: first,
      last: last,
      label: isFrom ? StayCalendarStrings.from : StayCalendarStrings.to,
      tone: StayCalKit.green,
    );
    if (picked == null || !mounted) return;
    setState(() {
      serverLine = null;
      final p = OwnerDates.only(picked);
      if (isFrom) {
        from = p;
        if (blockMode) {
          if (to.isBefore(from)) to = from;
        } else if (!to.isAfter(from)) {
          to = OwnerDates.addDays(from, 1);
        }
      } else {
        to = p;
      }
    });
  }

  Future<void> _toggleBlock(bool on) async {
    if (on && !editing && c.needsG11) {
      await PlanGate.showLimit(context, StayGateStringsCalendar.g11());
      return;
    }
    setState(() {
      blockMode = on;
      serverLine = null;
      blockError = StayBlockError.none;
      if (on) {
        if (to.isAfter(from)) to = OwnerDates.addDays(to, -1);
      } else if (!to.isAfter(from)) {
        to = OwnerDates.addDays(from, 1);
      }
    });
  }

  Future<void> save() async {
    setState(() {
      triedSave = true;
      serverLine = null;
    });
    if (blockMode) return _saveBlock();
    if (labelEmpty || !canSave) return;
    if (widget.entry == null && c.needsG10(to)) {
      await PlanGate.showLimit(context, StayGateStringsCalendar.g10(used: c.meter(StayMeterKeys.entries)?.used));
      return;
    }
    final draft = CalendarEntryDraft(
      id: bookingId,
      label: label.text.trim(),
      dateFrom: from,
      dateTo: to,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      finalAmount: money.finalAmount,
      receivedSoFar: money.paidInFull ? null : money.receivedSoFar,
      paidInFull: money.paidInFull,
      version: widget.entry?.version,
    );
    final r = widget.entry == null ? await c.create(draft) : await c.edit(draft);
    if (!mounted) return;
    await _handle(r, onOk: () => Navigator.of(context).pop());
  }

  Future<void> _saveBlock({bool confirm = false}) async {
    if (!canSave) return;
    final draft = StayBlockDraft(
      id: blockId,
      dateFrom: from,
      dateTo: to,
      reason: label.text.trim().isEmpty ? null : label.text.trim(),
      version: widget.existingBlock?.version,
    );
    final r = await c.saveBlock(draft, edit: widget.existingBlock != null, confirm: confirm);
    if (!mounted) return;
    if (r is OwnerRefused<StayBlockWrite> && r.type == OwnerErrorTypes.blockedRangeNeedsConfirm) {
      final inside = r.data['confirmedInside'];
      final open = r.data['openEnquiriesInside'];
      final n = inside is num ? inside.toInt() : 1;
      final q = open is num ? open.toInt() : 0;
      final go = await OwnerConfirm.ask(
        context,
        title: StayCalendarStrings.confirmedInside(n),
        body: q > 0 ? '${StayCalendarStrings.staysConfirmed} ${StayCalendarStrings.openEnquiriesFor(q)}' : StayCalendarStrings.staysConfirmed,
        confirm: StayCalendarStrings.blockAnyway,
        cancel: StayCalendarStrings.back,
        tone: ListingTone.forest,
        art: ListingArt.warning,
      );
      if (go && mounted) await _saveBlock(confirm: true);
      return;
    }
    if (r is OwnerRefused<StayBlockWrite> && (r.type == OwnerErrorTypes.blockedRangeOverlap || r.type == OwnerErrorTypes.blockedRangeInvalid)) {
      setState(() {
        blockError = r.type == OwnerErrorTypes.blockedRangeOverlap ? StayBlockError.overlap : StayBlockError.invalid;
        _errorFrom = from;
        _errorTo = to;
      });
      return;
    }
    await _handle(r, onOk: () => Navigator.of(context).pop());
  }

  Future<void> _handle(OwnerResult<dynamic> r, {required VoidCallback onOk}) async {
    switch (r) {
      case OwnerOk():
        onOk();
      case OwnerOffline():
        AppToast.error(OwnerSharedStrings.noConnection);
      case OwnerFailed():
        AppToast.error(OwnerSharedStrings.noConnection);
      case OwnerRefused():
        if (r.rateLimited) {
          AppToast.info(OwnerSharedStrings.tooManyTries);
          return;
        }
        if (await PlanGate.handleRefusal(context, r, StayGateStringsCalendar.fromRefusal)) return;
        if (!mounted) return;
        final line = switch (r.type) {
          OwnerErrorTypes.calendarOutsideWindow => StayCalendarStrings.outsideWindow,
          OwnerErrorTypes.phoneNotAllowed => StayCalendarStrings.noPhone,
          OwnerErrorTypes.moneyNoteInvalid => StayCalendarStrings.receivedAboveFinal,
          OwnerErrorTypes.entryNotManual => StayCalendarStrings.notManual,
          OwnerErrorTypes.staleEdit => OwnerSharedStrings.staleEdit,
          _ => r.message ?? OwnerSharedStrings.noConnection,
        };
        setState(() => serverLine = line);
    }
  }

  Future<void> _close() async {
    final nav = Navigator.of(context);
    if (!dirty) {
      nav.pop();
      return;
    }
    final discard = await OwnerConfirm.discard(context);
    if (discard && nav.mounted) nav.pop();
  }

  String get _title {
    if (blockMode) return widget.existingBlock != null || (!widget.startBlock) ? StayCalendarStrings.blockEditTitle : StayCalendarStrings.blockTitle;
    return widget.entry != null ? StayCalendarStrings.editTitle : StayCalendarStrings.addTitle;
  }

  String get _sub {
    if (blockMode) return widget.existingBlock != null || (!widget.startBlock) ? StayCalendarStrings.blockEditSub : StayCalendarStrings.blockSub;
    return StayCalendarStrings.addSub;
  }

  String get _saveLabel {
    if (!blockMode) return StayCalendarStrings.saveBooking;
    return widget.startBlock && widget.existingBlock == null ? StayCalendarStrings.blockSave : StayCalendarStrings.blockSaveEdit;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: SheetFrame(
        tone: ListingTone.forest,
        title: _title,
        subtitle: _sub,
        size: SheetSize.form,
        footer: SingleFlightButton(
          onPressed: canSave ? save : null,
          builder: (ctx, onPressed, busy) => PrimaryButton(label: _saveLabel, tone: StayCalKit.green, loading: busy, onPressed: onPressed),
        ),
        child: blockMode ? _blockBody() : _bookingBody(),
      ),
    );
  }

  Widget _label(String text, {String? right}) => Padding(
        padding: DS.insets(t: 10, b: 6),
        child: Row(
          children: [
            Expanded(child: Text(text, style: Ink3D.text(11.5, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
            if (right != null) Text(right, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
          ],
        ),
      );

  Widget _error(String text) => Padding(
        padding: DS.insets(t: 4),
        child: Semantics(liveRegion: true, child: Text(text, style: Ink3D.text(10.5, FontWeight.w600, DesignColors.error, letterSpacing: 0))),
      );

  Widget _dates({bool red = false}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: StayDateBox(label: StayCalendarStrings.from, date: from, red: red, onTap: () => _pick(true))),
          Gap.h(8),
          Expanded(child: StayDateBox(label: StayCalendarStrings.to, date: to, red: red, onTap: () => _pick(false))),
        ],
      );

  Widget _bookingBody() {
    final nameError = labelPhone ? StayCalendarStrings.noPhone : (triedSave && labelEmpty ? StayCalendarStrings.nameNeeded : null);
    final overlaps = overlapBookings;
    final info = overlaps > 0 ? StayCalendarStrings.alreadyBookings(overlaps) : (overlapBlocked ? StayCalendarStrings.alreadyBlocked : null);
    final entries = c.meter(StayMeterKeys.entries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(StayCalendarStrings.nameLabel, right: StayCalendarStrings.required),
        Semantics(
          label: '${StayCalendarStrings.nameLabel}, ${StayCalendarStrings.required.toLowerCase()}',
          child: PillField(
            tone: ListingTone.forest,
            controller: label,
            maxLength: StayEntryRules.labelMax,
            counterText: '',
            inputFormatters: noEmojiInputFormatters,
            errorText: nameError,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        _dates(),
        if (info != null)
          Padding(
            padding: DS.insets(t: 6),
            child: Row(
              children: [
                ExcludeSemantics(child: Art3D(asset: ListingArt.bulb, size: 14)),
                Gap.h(6),
                Expanded(child: Text(info, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.sub, letterSpacing: 0))),
              ],
            ),
          ),
        Gap.v(12),
        MoneyNotesFields(controller: money, look: OwnerLook.stay, finalHint: StayCalendarStrings.wholeStay),
        _label(StayCalendarStrings.note, right: StayCalendarStrings.optional),
        PillField(
          tone: ListingTone.forest,
          controller: note,
          maxLength: StayEntryRules.noteMax,
          counterText: '',
          inputFormatters: noEmojiInputFormatters,
          errorText: notePhone ? StayCalendarStrings.noPhone : null,
          textCapitalization: TextCapitalization.sentences,
        ),
        Gap.v(10),
        ToggleRow(
          tone: ListingTone.forest,
          label: StayCalendarStrings.blockToggle,
          sublabel: StayCalendarStrings.blockToggleSub,
          value: false,
          filled: true,
          onChanged: _toggleBlock,
        ),
        Gap.v(10),
        StayPrivacyBox(text: StayCalendarStrings.privacyLine),
        if (entries != null) _meterLine(StayCalendarStrings.bookingsYouAdded, entries, PlanGate.paymentOn ? null : StayCalendarStrings.bookingsAddedOff(entries.used)),
        Padding(
          padding: DS.insets(t: 8),
          child: Row(children: [
            ExcludeSemantics(child: Art3D(asset: ListingArt.alarmClock, size: 14)),
            Gap.h(6),
            Expanded(child: Text(StayCalendarStrings.removed90, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0))),
          ]),
        ),
        if (serverLine != null) _error(serverLine!),
        Gap.v(8),
      ],
    );
  }

  Widget _meterLine(String label, Meter m, String? offText) => Padding(
        padding: DS.insets(t: 12),
        child: Row(
          children: [
            Expanded(child: Text(offText ?? label, style: Ink3D.text(11, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
            if (offText == null)
              Text(PlanGate.canUpgrade ? StayCalendarStrings.onFree(m.used, m.limit) : StayCalendarStrings.meterCount(m.used, m.limit),
                  style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
          ],
        ),
      );

  Widget _blockBody() {
    final red = blockError != StayBlockError.none && !datesChangedSinceError;
    final blocks = c.meter(StayMeterKeys.blocks);
    final editMode = widget.existingBlock != null || !widget.startBlock;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(StayCalendarStrings.reason, right: editMode ? StayCalendarStrings.reasonHintPrivate : StayCalendarStrings.reasonHintCreate),
        PillField(
          tone: ListingTone.forest,
          controller: label,
          maxLength: StayEntryRules.labelMax,
          counterText: '',
          inputFormatters: noEmojiInputFormatters,
          errorText: labelPhone ? StayCalendarStrings.noPhone : null,
        ),
        _dates(red: red),
        if (red) ...[
          Gap.v(10),
          if (blockError == StayBlockError.overlap) StayRedBox(text: StayCalendarStrings.blockOverlap),
          Padding(
            padding: DS.insets(t: 8),
            child: Text(StayCalendarStrings.blockRule, style: Ink3D.text(10.5, FontWeight.w500, Ink3D.grey, height: 1.4, letterSpacing: 0)),
          ),
        ],
        if (!editMode || widget.existingBlock == null) ...[
          Gap.v(10),
          ToggleRow(
            tone: ListingTone.forest,
            label: StayCalendarStrings.blockToggle,
            sublabel: StayCalendarStrings.blockToggleSub,
            value: true,
            filled: true,
            onChanged: widget.startBlock ? null : _toggleBlock,
          ),
        ],
        if (!red) ...[
          Gap.v(10),
          Container(
            padding: DS.sym(h: 12, v: 10),
            decoration: BoxDecoration(color: StayLook.amberSoft, borderRadius: DS.circular(12)),
            child: Row(
              children: [
                ExcludeSemantics(child: Art3D(asset: ListingArt.warning, size: 18)),
                Gap.h(8),
                Expanded(child: Text(StayCalendarStrings.travellersSeeFull, style: Ink3D.text(11, FontWeight.w600, StayLook.amberText, letterSpacing: 0))),
              ],
            ),
          ),
        ],
        if (blocks != null && !red) _meterLine(StayCalendarStrings.blocksMeter, blocks, PlanGate.paymentOn ? null : StayCalendarStrings.blocksOff(blocks.used)),
        if (serverLine != null) _error(serverLine!),
        Gap.v(8),
      ],
    );
  }
}

class StayDateBox extends StatelessWidget {
  const StayDateBox({super.key, required this.label, required this.date, required this.onTap, this.red = false});

  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final bool red;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: DS.insets(t: 10, b: 6),
            child: Text(label, style: Ink3D.text(11.5, FontWeight.w700, Ink3D.title, letterSpacing: 0)),
          ),
          Semantics(
            button: true,
            label: '$label date, ${StayCalendarStrings.spokenDate(date)} ${date.year}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: DS.circular(14),
              onTap: onTap,
              child: Container(
                constraints: BoxConstraints(minHeight: DS.s(48)),
                padding: DS.sym(h: 14),
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  borderRadius: DS.circular(14),
                  border: Border.all(color: red ? DesignColors.error : DesignColors.border, width: DS.s(1.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(StayCalendarStrings.longDate(date), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12.5, FontWeight.w600, Ink3D.title, letterSpacing: 0)),
                    ),
                    Icon(Icons.arrow_drop_down_rounded, size: DS.s(20), color: StayLook.indigoText),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
}

class StayRedBox extends StatelessWidget {
  const StayRedBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          padding: DS.sym(h: 12, v: 10),
          decoration: BoxDecoration(color: StayLook.redSoft, borderRadius: DS.circular(10)),
          child: Row(
            children: [
              ExcludeSemantics(child: Art3D(asset: ListingArt.warning, size: 18)),
              Gap.h(8),
              Expanded(child: Text(text, style: Ink3D.text(11, FontWeight.w700, StayLook.redText, letterSpacing: 0))),
            ],
          ),
        ),
      );
}

class StayPrivacyBox extends StatelessWidget {
  const StayPrivacyBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 12, v: 10),
        decoration: BoxDecoration(color: StayLook.tealSoft, borderRadius: DS.circular(12)),
        child: Row(
          children: [
            ExcludeSemantics(child: Art3D(asset: ListingArt.shield, size: 22)),
            Gap.h(10),
            Expanded(child: Text(text, style: Ink3D.text(10.5, FontWeight.w600, StayLook.tealDeep.text, height: 1.4, letterSpacing: 0))),
          ],
        ),
      );
}
