import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../design/design.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../owner_core/calendar/calendar_api.dart';
import '../../owner_core/calendar/models/calendar_models.dart';
import '../../owner_core/data/owner_error_types.dart';
import '../../owner_core/data/owner_result.dart';
import '../../owner_core/data/single_flight.dart';
import '../../owner_core/json/owner_dates.dart';
import '../../../utils/money_format.dart';
import '../../owner_core/money/money_note_math.dart';
import '../../owner_core/money/money_notes_fields.dart';
import '../../owner_core/money/phone_guard.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/sheets/owner_sheet.dart';
import '../../owner_core/strings/owner_shared_strings.dart';
import '../availability/taxi_availability_api.dart';
import '../availability/taxi_availability_store.dart';
import '../strings/taxi_availability_strings.dart';
import '../strings/taxi_calendar_strings.dart';
import '../taxi_driver_deps.dart';
import '../strings/taxi_gate_strings_calendar.dart';
import 'taxi_calendar_controller.dart';
import 'taxi_calendar_widgets.dart';
import '../../owner_core/sheets/sheet_disposables.dart';

enum TaxiTripField { label, date, from, to, note }

class TaxiTripForm extends ChangeNotifier {
  TaxiTripForm({required this.controller, DateTime? date, this.editing})
      : id = editing?.id ?? const Uuid().v4(),
        label = TextEditingController(text: editing?.label ?? ''),
        from = TextEditingController(text: editing?.fromPlace ?? ''),
        to = TextEditingController(text: editing?.toPlace ?? ''),
        note = TextEditingController(text: editing?.note ?? ''),
        money = MoneyNotesController(finalAmount: editing?.finalAmount, receivedSoFar: editing?.receivedSoFar, paidInFull: editing?.paidInFull ?? false),
        date = editing?.dateFrom ?? firstFreeDay(date ?? controller.serverToday),
        time = OwnerDates.time(editing?.timeOfDay) {
    for (final c in [label, from, to, note]) {
      c.addListener(_changed);
    }
    money.addListener(_changed);
    _start = _snapshot();
  }

  static const int labelMax = 60;
  static const int placeMax = 80;
  static const int noteMax = 200;

  final TaxiCalendarController controller;
  final CalendarEntry? editing;
  final String id;
  final TextEditingController label;
  final TextEditingController from;
  final TextEditingController to;
  final TextEditingController note;
  final MoneyNotesController money;
  final FocusNode labelFocus = FocusNode();
  DateTime date;
  ({int hour, int minute})? time;
  final Map<TaxiTripField, String> errors = {};
  bool stale = false;
  late final String _start;
  bool _disposed = false;

  bool get isEdit => editing != null;

  static DateTime firstFreeDay(DateTime from) {
    var d = OwnerDates.only(from);
    for (var i = 0; i < 400 && TaxiDriverDeps.isDayOff(d); i++) {
      d = OwnerDates.addDays(d, 1);
    }
    return d;
  }

  bool get _dateMoved {
    final was = editing?.dateFrom;
    return was == null || !OwnerDates.sameDay(was, date);
  }

  String _snapshot() => [label.text, from.text, to.text, note.text, money.finalText.text, money.receivedText.text, money.paidInFull, date, time].join('|');

  bool get dirty => _snapshot() != _start;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void setDate(DateTime d) {
    date = OwnerDates.only(d);
    if (_dateMoved && TaxiDriverDeps.isDayOff(date)) {
      errors[TaxiTripField.date] = TaxiAvailabilityStrings.dayIsOff;
    } else {
      errors.remove(TaxiTripField.date);
    }
    _changed();
  }

  void setTime(({int hour, int minute})? t) {
    time = t;
    _changed();
  }

  int get overlap => controller.bookingsOn(date);

  CalendarWindow? get window => (controller.monthOf(date) ?? controller.current)?.window;

  DateTime get firstDay => window?.manualFrom ?? OwnerDates.addDays(controller.serverToday, -7);

  DateTime get lastDay => window?.manualTo ?? OwnerDates.addDays(controller.serverToday, PlanGate.limit(PlanKey.upcomingDays));

  String? _clean(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  bool validate() {
    errors.clear();
    final l = label.text.trim();
    if (l.isEmpty) errors[TaxiTripField.label] = TaxiCalendarStrings.labelEmpty;
    for (final e in {TaxiTripField.label: label, TaxiTripField.from: from, TaxiTripField.to: to, TaxiTripField.note: note}.entries) {
      if (!errors.containsKey(e.key) && PhoneGuard.hasPhone(e.value.text)) errors[e.key] = OwnerSharedStrings.noPhone;
    }
    if (date.isBefore(OwnerDates.only(firstDay)) || date.isAfter(OwnerDates.only(lastDay))) {
      errors[TaxiTripField.date] = TaxiCalendarStrings.outsideWindow;
    } else if (_dateMoved && TaxiDriverDeps.isDayOff(date)) {
      errors[TaxiTripField.date] = TaxiAvailabilityStrings.dayIsOff;
    }
    _changed();
    return errors.isEmpty && money.error == null;
  }

  CalendarEntryDraft draft() => CalendarEntryDraft(
        id: id,
        label: label.text.trim(),
        dateFrom: date,
        dateTo: date,
        timeOfDay: time == null ? null : OwnerDates.timeText(time!.hour, time!.minute),
        fromPlace: _clean(from),
        toPlace: _clean(to),
        note: _clean(note),
        finalAmount: money.finalAmount,
        receivedSoFar: money.paidInFull ? null : money.receivedSoFar,
        paidInFull: money.paidInFull,
        version: editing?.version,
      );

  void applyRefusal(OwnerRefused<dynamic> r) {
    if (r.type == OwnerErrorTypes.phoneNotAllowed) {
      errors[TaxiTripField.note] = OwnerSharedStrings.noPhone;
    } else if (r.type == OwnerErrorTypes.calendarOutsideWindow) {
      errors[TaxiTripField.date] = TaxiCalendarStrings.outsideWindow;
    } else if (r.type == OwnerErrorTypes.dayIsOff) {
      errors[TaxiTripField.date] = TaxiAvailabilityStrings.dayIsOff;
    } else if (OwnerRefusal.stale(r)) {
      stale = true;
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final c in [label, from, to, note]) {
      c.dispose();
    }
    labelFocus.dispose();
    money.dispose();
    super.dispose();
  }
}

abstract final class TaxiTripSheet {
  static Future<bool> show(BuildContext context, {required TaxiCalendarController controller, DateTime? date, CalendarEntry? editing}) async {
    if (editing == null && PlanGate.canUpgrade && controller.entriesFull) {
      await PlanGate.showLimit(context, TaxiGateStringsCalendar.g10(limit: controller.entriesMeter.limit));
      return false;
    }
    final form = TaxiTripForm(controller: controller, date: date, editing: editing);
    final saved = await OwnerSheet.show<bool>(
      context,
      look: TaxiCal.look,
      title: editing == null ? TaxiCalendarStrings.addTripTitle : TaxiCalendarStrings.editTripTitle,
      subtitle: TaxiCalendarStrings.addTripSub,
      dirty: () => form.dirty,
      child: (_) => SheetDisposables(notifiers: [form], child: TaxiTripFields(form: form)),
      footer: (c) => SingleFlightButton(
        onPressed: () => save(c, form),
        builder: (c, onPressed, busy) => PrimaryButton(label: TaxiCalendarStrings.saveTrip, tone: TaxiCal.kit, loading: busy, onPressed: onPressed),
      ),
    );
    return saved == true;
  }

  static Future<void> save(BuildContext context, TaxiTripForm form) async {
    if (!form.validate()) {
      if (form.errors.containsKey(TaxiTripField.label)) form.labelFocus.requestFocus();
      return;
    }
    final c = form.controller;
    if (!form.isEdit && PlanGate.canUpgrade && c.entriesFull) {
      await PlanGate.showLimit(context, TaxiGateStringsCalendar.g10(limit: c.entriesMeter.limit));
      return;
    }
    final r = form.isEdit ? await c.edit(form.draft()) : await c.create(form.draft());
    if (!context.mounted) return;
    switch (r) {
      case OwnerOk():
        Navigator.of(context).pop(true);
      case OwnerRefused():
        if (r.type == TaxiCalendarStrings.entryEndedType) {
          AppToast.info(TaxiCalendarStrings.entryEnded);
          c.reload().ignore();
          Navigator.of(context).pop(false);
          return;
        }
        if (PlanGate.handleInactive(r)) {
          c.reload().ignore();
          Navigator.of(context).pop(false);
          return;
        }
        if (await PlanGate.handleRefusal(context, r, TaxiGateStringsCalendar.fromRefusal)) return;
        if (TaxiHourlyLimit.toastIfLimited(r)) return;
        if (r.statusCode == 429) {
          AppToast.error(OwnerSharedStrings.tooManyTries);
          return;
        }
        form.applyRefusal(r);
        if (r.type == OwnerErrorTypes.dayIsOff) TaxiAvailabilityStore.maybe?.refresh(force: true).ignore();
        if (r.type == OwnerErrorTypes.moneyNoteInvalid ||
            (r.type != OwnerErrorTypes.phoneNotAllowed && r.type != OwnerErrorTypes.calendarOutsideWindow && r.type != OwnerErrorTypes.dayIsOff && !OwnerRefusal.stale(r))) {
          AppToast.error(r.message ?? OwnerSharedStrings.noConnection);
        }
      case OwnerOffline():
      case OwnerFailed():
        AppToast.error(OwnerSharedStrings.noConnection);
    }
  }
}

class TaxiTripFields extends StatelessWidget {
  const TaxiTripFields({super.key, required this.form});

  final TaxiTripForm form;

  static Widget label(String text, {String? caption}) => Padding(
        padding: EdgeInsets.only(bottom: DS.gv(6)),
        child: Row(
          children: [
            Expanded(child: Text(text, style: Ink3D.text(12, FontWeight.w700, Ink3D.title, letterSpacing: 0))),
            if (caption != null) Text(caption, style: Ink3D.text(11, FontWeight.w500, Ink3D.grey, letterSpacing: 0)),
          ],
        ),
      );

  Future<void> _pickDate(BuildContext context) async {
    final d = await TemplateCalendarPopup.pickDate(
      context,
      initial: form.date,
      first: form.firstDay,
      last: form.lastDay,
      label: TaxiCalendarStrings.date,
      tone: TaxiCal.kit,
    );
    if (d != null) form.setDate(d);
  }

  Future<void> _pickTime(BuildContext context) async {
    final t = form.time;
    final picked = await TemplateTimePopup.pick(
      context,
      initial: t == null ? const TimeOfDay(hour: 9, minute: 0) : TimeOfDay(hour: t.hour, minute: t.minute),
      label: TaxiCalendarStrings.time,
      tone: TaxiCal.kit,
    );
    if (picked != null) form.setTime((hour: picked.hour, minute: picked.minute));
  }

  Widget _picker({required String value, required VoidCallback onTap, String? error, Widget? clear, required String semantics}) => Semantics(
        button: true,
        label: semantics,
        child: InkWell(
          onTap: onTap,
          borderRadius: DS.circular(14),
          child: Container(
            constraints: BoxConstraints(minHeight: DS.s(48)),
            padding: DS.sym(h: 14, v: 10),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              borderRadius: DS.circular(14),
              border: Border.all(color: error == null ? TaxiCal.coral.line : DesignColors.error, width: DS.s(1)),
            ),
            child: Row(
              children: [
                Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13.5, FontWeight.w600, Ink3D.title, letterSpacing: 0))),
                ?clear,
                Icon(Icons.arrow_drop_down_rounded, size: DS.s(22), color: TaxiCal.accent),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: form,
      builder: (context, _) {
        final e = form.errors;
        final t = form.time;
        final overlap = form.overlap;
        final meter = form.controller.entriesMeter;
        final onFree = PlanGate.canUpgrade;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (form.stale)
              Padding(
                padding: EdgeInsets.only(bottom: DS.gv(10)),
                child: Text(OwnerSharedStrings.staleEdit, style: Ink3D.text(12, FontWeight.w600, DesignColors.error, letterSpacing: 0)),
              ),
            label(TaxiCalendarStrings.nameOrLabel, caption: TaxiCalendarStrings.required),
            TaxiInput(
              controller: form.label,
              focusNode: form.labelFocus,
              errorText: e[TaxiTripField.label],
              inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TaxiTripForm.labelMax)],
              semanticsLabel: TaxiCalendarStrings.nameOrLabel,
            ),
            Gap.v(12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label(TaxiCalendarStrings.date),
                      _picker(
                        value: TaxiCalendarStrings.dateField(form.date),
                        onTap: () => _pickDate(context),
                        error: e[TaxiTripField.date],
                        semantics: '${TaxiCalendarStrings.date}, ${TaxiCalendarStrings.dateField(form.date)}',
                      ),
                    ],
                  ),
                ),
                Gap.h(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label(TaxiCalendarStrings.time, caption: TaxiCalendarStrings.optional),
                      _picker(
                        value: t == null ? '' : TaxiCalendarStrings.timeAm(t.hour, t.minute),
                        onTap: () => _pickTime(context),
                        semantics: TaxiCalendarStrings.time,
                        clear: t == null
                            ? null
                            : InkWell(
                                onTap: () => form.setTime(null),
                                child: Padding(padding: DS.all(2), child: Icon(Icons.close_rounded, size: DS.s(16), color: Ink3D.grey)),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (e[TaxiTripField.date] != null)
              Padding(
                padding: EdgeInsets.only(top: DS.gv(4)),
                child: Text(e[TaxiTripField.date]!, style: Ink3D.text(11.5, FontWeight.w500, DesignColors.error, letterSpacing: 0)),
              ),
            if (overlap > 0)
              Padding(
                padding: EdgeInsets.only(top: DS.gv(8)),
                child: Row(
                  children: [
                    Art3D(asset: ListingArt.bulb, size: 14),
                    Gap.h(6),
                    Expanded(child: Text(TaxiCalendarStrings.overlap(overlap), style: Ink3D.text(11.5, FontWeight.w500, Ink3D.grey, letterSpacing: 0))),
                  ],
                ),
              ),
            Gap.v(12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label(TaxiCalendarStrings.from),
                      TaxiInput(
                        controller: form.from,
                        errorText: e[TaxiTripField.from],
                        inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TaxiTripForm.placeMax)],
                        semanticsLabel: TaxiCalendarStrings.from,
                      ),
                    ],
                  ),
                ),
                Gap.h(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label(TaxiCalendarStrings.to),
                      TaxiInput(
                        controller: form.to,
                        errorText: e[TaxiTripField.to],
                        inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TaxiTripForm.placeMax)],
                        semanticsLabel: TaxiCalendarStrings.to,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Gap.v(14),
            TaxiMoneyFields(money: form.money),
            Gap.v(12),
            label(TaxiCalendarStrings.note, caption: TaxiCalendarStrings.optional),
            TaxiInput(
              controller: form.note,
              errorText: e[TaxiTripField.note],
              maxLines: 3,
              inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TaxiTripForm.noteMax)],
              semanticsLabel: TaxiCalendarStrings.note,
            ),
            Gap.v(12),
            const TaxiShieldNote(text: TaxiCalendarStrings.privacy),
            Gap.v(12),
            label(
              TaxiCalendarStrings.tripsYouAdded,
              caption: onFree ? TaxiCalendarStrings.meterOnFree(meter.used, meter.limit) : TaxiCalendarStrings.meter(meter.used, meter.limit),
            ),
            const TaxiFootLine(text: OwnerSharedStrings.removedAfter90),
          ],
        );
      },
    );
  }
}

class TaxiInput extends StatelessWidget {
  const TaxiInput({
    super.key,
    required this.controller,
    this.focusNode,
    this.errorText,
    this.inputFormatters,
    this.semanticsLabel,
    this.prefixText,
    this.keyboardType,
    this.enabled = true,
    this.maxLines = 1,
    this.hintText,
    this.alert = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final String? semanticsLabel;
  final String? prefixText;
  final TextInputType? keyboardType;
  final bool enabled;
  final int maxLines;
  final String? hintText;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: DS.circular(14), borderSide: BorderSide(color: c, width: DS.s(w)));
    return Semantics(
      label: semanticsLabel,
      textField: true,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        minLines: 1,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: Ink3D.text(13.5, FontWeight.w600, Ink3D.title, letterSpacing: 0),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: enabled ? DesignColors.surface : TaxiCal.softFill,
          prefixText: prefixText,
          hintText: hintText,
          hintStyle: Ink3D.text(13.5, FontWeight.w600, Ink3D.hint, letterSpacing: 0),
          prefixStyle: Ink3D.text(13.5, FontWeight.w600, Ink3D.title, letterSpacing: 0),
          contentPadding: DS.sym(h: 14, v: 13),
          errorText: errorText,
          errorMaxLines: 2,
          errorStyle: Ink3D.text(11.5, FontWeight.w500, DesignColors.error, letterSpacing: 0),
          enabledBorder: border(alert ? DesignColors.error : TaxiCal.coral.line),
          disabledBorder: border(Ink3D.line),
          focusedBorder: border(alert ? DesignColors.error : TaxiCal.ownDot, 1.4),
          errorBorder: border(DesignColors.error),
          focusedErrorBorder: border(DesignColors.error, 1.4),
        ),
      ),
    );
  }
}

class TaxiMoneyFields extends StatelessWidget {
  const TaxiMoneyFields({super.key, required this.money});

  final MoneyNotesController money;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: money,
      builder: (context, _) {
        final note = money.note;
        final balance = MoneyNoteMath.balance(note);
        final error = money.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaxiTripFields.label(OwnerSharedStrings.moneyNotes, caption: OwnerSharedStrings.onlyYouSee),
            Gap.v(4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TaxiTripFields.label(OwnerSharedStrings.finalAmount, caption: TaxiCalendarStrings.finalHint),
                      TaxiInput(
                        controller: money.finalText,
                        prefixText: '${Money.symbol} ',
                        keyboardType: TextInputType.number,
                        inputFormatters: MoneyInput.formatters,
                        semanticsLabel: OwnerSharedStrings.finalAmount,
                      ),
                    ],
                  ),
                ),
                Gap.h(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TaxiTripFields.label(OwnerSharedStrings.receivedSoFar),
                      TaxiInput(
                        controller: money.receivedText,
                        prefixText: '${Money.symbol} ',
                        keyboardType: TextInputType.number,
                        enabled: !money.paidInFull,
                        inputFormatters: MoneyInput.formatters,
                        semanticsLabel: OwnerSharedStrings.receivedSoFar,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (error != null)
              Padding(
                padding: EdgeInsets.only(top: DS.gv(4)),
                child: Text(MoneyNotesController.messageOf(error), style: Ink3D.text(11.5, FontWeight.w500, DesignColors.error, letterSpacing: 0)),
              ),
            if (balance != null) ...[
              Gap.v(10),
              Semantics(
                label: '${OwnerSharedStrings.balanceToCollect} ${Money.exact(balance)}',
                excludeSemantics: true,
                child: Container(
                  padding: DS.sym(h: 14, v: 10),
                  decoration: BoxDecoration(
                    color: TaxiCal.amberFill,
                    borderRadius: DS.circular(14),
                    border: Border.all(color: TaxiCal.look.lockLine, width: DS.s(1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(OwnerSharedStrings.balanceToCollect, style: Ink3D.text(12.5, FontWeight.w700, TaxiCal.amber, letterSpacing: 0)),
                            Text(OwnerSharedStrings.balanceHint, style: Ink3D.text(10.5, FontWeight.w500, TaxiCal.amber, letterSpacing: 0)),
                          ],
                        ),
                      ),
                      Text(Money.exact(balance), style: Ink3D.text(17, FontWeight.w700, TaxiCal.amber, letterSpacing: 0)),
                    ],
                  ),
                ),
              ),
            ],
            Gap.v(10),
            Container(
              padding: DS.sym(h: 12, v: 2),
              decoration: BoxDecoration(color: TaxiCal.softFill, borderRadius: DS.circular(14)),
              child: ToggleRow(
                tone: TaxiCal.look.tone,
                label: OwnerSharedStrings.paidInFull,
                sublabel: OwnerSharedStrings.paidInFullHint,
                value: money.paidInFull,
                onChanged: (v) => money.paidInFull = v,
              ),
            ),
          ],
        );
      },
    );
  }
}
