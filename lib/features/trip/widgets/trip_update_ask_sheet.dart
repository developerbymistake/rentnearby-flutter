import 'package:flutter/material.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/replies_kit.dart';
import 'package:get/get.dart';
import '../../../utils/app_toast.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_v2_easy.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_enquiry_rules.dart';
import 'trip_change_request_sheet.dart';
import 'trip_sheet_frame.dart';

class TripUpdateAskSheet {
  static Future<void> afterDaysEdit() async {
    final ctx = Get.context;
    if (ctx == null) return;
    final res = TripPlanController.to.staleAsks();
    if (res.hasAffected && ctx.mounted) await show(ctx, res);
  }

  static Future<void> show(BuildContext context, SettingsSaveResult res) async {
    final c = TripPlanController.to;
    final open = <TripEnquiryModel>[
      for (final e in [...res.openAffected, ...res.openTaxiAffected])
        if (!e.isBooked) e,
    ];
    final confirmed = [for (final e in res.confirmedAffected) if (!e.isTaxi) e];
    final taxis = [for (final e in res.bookedTaxiAffected) if (e.isTaxi) e];
    if (open.isEmpty && confirmed.isEmpty && taxis.isEmpty) return;
    final change = c.lastSettingsChange;
    final peopleOnly = change.people && !change.dates && !change.days;
    final go = await TripSheetFrame.show<bool>(
      context,
      _UpdateBody(open: open, confirmed: confirmed, confirmedTaxis: taxis, plan: c, peopleOnly: peopleOnly),
    );
    if (go != true) return;
    for (final e in confirmed) {
      if (!context.mounted) return;
      final p = c.plan.value;
      final home = p != null && p.isMultiCity ? TripEnquiryRules.homeLegIndex(e, p) : null;
      final k = home != null && p?.legAt(home) != null ? home : (p?.legIndexOf(e.day ?? 1) ?? 1);
      final first = p == null ? null : c.dateOf(p.legStart(k));
      final nights = p?.legDayCount(k) ?? 1;
      await TripChangeRequestSheet.show(
        context,
        enquiry: e,
        prefill: c.settings,
        checkIn: first,
        checkOut: first == null ? null : DateTime(first.year, first.month, first.day + nights),
      );
    }
  }
}

class _Row {
  const _Row(this.title, this.sub);

  final String title;
  final String sub;
}

class _UpdateBody extends StatefulWidget {
  const _UpdateBody({
    required this.open,
    required this.confirmed,
    required this.confirmedTaxis,
    required this.plan,
    this.peopleOnly = false,
  });

  final List<TripEnquiryModel> open;
  final List<TripEnquiryModel> confirmed;
  final List<TripEnquiryModel> confirmedTaxis;
  final TripPlanController plan;
  final bool peopleOnly;

  @override
  State<_UpdateBody> createState() => _UpdateBodyState();
}

class _UpdateBodyState extends State<_UpdateBody> {
  bool _busy = false;

  TripPlanController get _c => widget.plan;

  int _legOf(TripEnquiryModel e) {
    final p = _c.plan.value;
    if (p == null) return 1;
    final home = p.isMultiCity && !e.isTaxi ? TripEnquiryRules.homeLegIndex(e, p) : null;
    if (home != null && p.legAt(home) != null) return home;
    final day = e.isTaxi ? (e.days.isEmpty ? null : e.days.reduce((a, b) => a < b ? a : b)) : e.day;
    return p.legIndexOf(day ?? 1);
  }

  String _oldRange(TripEnquiryModel e) {
    final a = e.checkIn;
    final b = e.checkOut;
    if (a == null) return '';
    return TripStringsV2Easy.stayDates(a, b ?? DateTime(a.year, a.month, a.day + 1));
  }

  List<int> _newTaxiDays() {
    final p = _c.plan.value;
    return p == null ? const [] : [for (final d in p.days) d.day];
  }

  List<int> _taxiDaysAfter(TripEnquiryModel e) {
    final p = _c.plan.value;
    if (p == null) return const [];
    final k = e.cityLeg ?? _legOf(e);
    final all = [for (final d in p.daysOf(k)) d.day];
    final old = [...e.days]..sort();
    final fromOne = old.isNotEmpty && all.isNotEmpty && old.first == all.first && old.last - old.first + 1 == old.length;
    final days = fromOne ? all : [for (final d in old) if (all.contains(d)) d];
    return days.take(TripConstants.maxLeadDays).toList();
  }

  ({int nights, String range, String city}) _now(TripEnquiryModel e) {
    final p = _c.plan.value;
    final k = _legOf(e);
    final nights = p?.legDayCount(k) ?? 1;
    final first = p == null ? null : _c.dateOf(p.legStart(k));
    final range = first == null ? '' : TripStringsV2Easy.stayDates(first, DateTime(first.year, first.month, first.day + nights));
    return (nights: nights, range: range, city: p == null ? '' : p.cityNameOf(p.legStart(k)));
  }

  String _oldPeople(TripEnquiryModel e) {
    final text = TripStrings.peopleText((e.context.adults ?? 0) + (e.context.kids ?? 0));
    return text.isEmpty ? TripStringsV2Find.yourGroup : text;
  }

  String get _nowPeople => TripStrings.peopleText(_c.settings.peopleCount);

  List<_Row> _rows(List<TripEnquiryModel> list) => [
        for (final e in list)
          if (widget.peopleOnly)
            _Row(
              e.isTaxi ? TripStringsV2Find.taxiLine(e.listingName) : e.listingName,
              TripStringsV2Find.peopleChange(_oldPeople(e), _nowPeople),
            )
          else if (e.isTaxi)
            _Row(
              TripStringsV2Find.taxiLine(e.listingName),
              TripStringsV2Find.askedChange(
                  TripStringsV2Find.dayRange(e.days), TripStringsV2Find.dayRange(_taxiDaysAfter(e))),
            )
          else
            _Row(e.listingName, TripStringsV2Find.stayChange(_oldRange(e), _now(e).range, _now(e).nights)),
      ];

  String _body(TripEnquiryModel e) {
    if (widget.peopleOnly) {
      return TripStringsV2Find.updatePeopleBody(
          e.isTaxi ? TripStringsV2Find.kindTaxi : TripStringsV2Find.kindStay, _oldPeople(e), _nowPeople);
    }
    if (e.isTaxi) {
      final days = _taxiDaysAfter(e);
      return TripStringsV2Find.updateTaxiBody(
          TripStringsV2Find.dayRange(e.days), _newTaxiDays().length, TripStringsV2Find.dayRange(days));
    }
    final n = _now(e);
    return TripStringsV2Find.updateAskBody(
        TripStringsV2Find.kindStay, _oldRange(e), n.city, TripStringsV2Find.nightsText(n.nights), n.range);
  }

  Future<void> _update() async {
    if (_busy) return;
    setState(() => _busy = true);
    final enquiries = TripEnquiryController.to;
    var failed = false;
    for (final e in widget.open) {
      final live = _c.enquiryList.firstWhereOrNull((x) => x.id == e.id) ?? e;
      if (live.isWithdrawable) await enquiries.withdraw(e.id);
      final p = _c.plan.value;
      if (p == null) continue;
      final k = _legOf(e);
      if (e.isTaxi) {
        final days = _taxiDaysAfter(e);
        if (days.isEmpty) continue;
        final batch = await enquiries.sendLead(
          days: days,
          taxiIds: [e.listingId],
          pickupTime: e.context.pickupTime,
          pickupPlace: e.context.pickupPlace,
        );
        if (batch == null) failed = true;
      } else {
        final batch = await enquiries.sendEnquiry(day: p.legStart(k), stayIds: [e.listingId], nights: p.legDayCount(k));
        if (batch == null) failed = true;
      }
    }
    for (final e in widget.confirmedTaxis) {
      if (!await enquiries.updateLead(e.id)) failed = true;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (failed) {
      AppToast.error(TripStringsV2Find.updateFailed);
      return;
    }
    if (widget.open.isNotEmpty || widget.confirmedTaxis.isNotEmpty) AppToast.success(TripStringsV2Find.updated);
    Navigator.pop(context, true);
  }

  Widget _line(_Row r) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: RepliesTone.accent, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w600, color: DesignColors.textStrong)),
                  Text(r.sub,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11.5, color: DesignColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final all = [...widget.open, ...widget.confirmedTaxis, ...widget.confirmed];
    final first = all.firstWhere((e) => !e.isTaxi, orElse: () => all.first);
    final rows = [..._rows(widget.open), ..._rows(widget.confirmedTaxis), ..._rows(widget.confirmed)];
    return TripSheetFrame(
      title: TripStringsV2Find.updateAskTitle,
      description: _body(first),
      children: [
        TemplateStagger(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        for (final r in rows) _line(r),
        if (widget.confirmed.isNotEmpty || widget.confirmedTaxis.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(TripStringsV2Find.confirmedRow((widget.confirmedTaxis.isNotEmpty ? widget.confirmedTaxis : widget.confirmed).first.listingName),
              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: DesignColors.textMuted, height: 1.35)),
        ],
        const SizedBox(height: 16),
        TripButton(
          label: TripStringsV2Find.updateAsk,
          height: 52,
          loading: _busy,
          onPressed: _busy ? null : _update,
        ),
        const SizedBox(height: 8),
        Text(widget.peopleOnly ? TripStringsV2Find.updatePeopleNote : TripStringsV2Find.updateNote,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: DesignColors.textMuted)),
        const SizedBox(height: 4),
        TextLink(label: TripStringsV2Find.keepAsIs, onTap: _busy ? null : () => Navigator.pop(context, false), tone: KitTone.trip),
          ],
        ),
      ],
    );
  }
}
