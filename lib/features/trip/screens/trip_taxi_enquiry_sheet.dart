import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_trip_replies.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../utils/input_formatters.dart';
import '../../taxi/models/taxi_browse_item.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../controllers/trip_supply_controller.dart';
import '../data/trip_enquiry_repository.dart';
import '../models/trip_enquiry_model.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a3.dart';
import '../trip_strings_v2_find.dart';
import '../utils/trip_enquiry_rules.dart';
import '../utils/trip_format.dart';
import '../utils/trip_stay_base.dart';
import '../widgets/trip_send_result_sheet.dart';
import '../widgets/trip_sheet_frame.dart';
import 'trip_dates_sheet.dart';

class TripTaxiEnquirySheet {
  static const TimeOfDay defaultTime = TimeOfDay(hour: 9, minute: 0);
  static const int placeMax = 80;

  static Future<TripEnquiryBatch?> show(
    BuildContext context, {
    required TaxiBrowseItem driver,
    required List<int> days,
  }) async {
    if (days.isEmpty) return null;
    final batch = await TripSheetFrame.show<TripEnquiryBatch>(context, _EnquiryBody(driver: driver, days: days));
    if (batch == null) return null;
    final left = batch.asksLeft;
    if (left != null) TripSupplyController.to.asksLeft.value = left;
    if (context.mounted) {
      await TripSendResultSheet.show(context, batch: batch, names: {driver.id: driver.driverName}, taxi: true);
    }
    return batch;
  }
}

class _EnquiryBody extends StatefulWidget {
  const _EnquiryBody({required this.driver, required this.days});

  final TaxiBrowseItem driver;
  final List<int> days;

  @override
  State<_EnquiryBody> createState() => _EnquiryBodyState();
}

class _EnquiryBodyState extends State<_EnquiryBody> {
  final _c = TripPlanController.to;
  late final List<int> _days;
  late TimeOfDay _time;
  late final TextEditingController _place;
  bool _sending = false;
  bool _limited = false;
  String? _limitBody;

  @override
  void initState() {
    super.initState();
    _days = [for (final d in widget.days) if (!_c.isDayPast(d)) d]..sort();
    _time = TripTaxiEnquirySheet.defaultTime;
    _place = TextEditingController(text: _startName() ?? '');
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  String? _startName() {
    final p = _c.plan.value;
    if (p == null || _days.isEmpty) return null;
    return TripStayBase.nameOf(p, p.legIndexOf(_days.first), _c.enquiryList);
  }

  Map<int, List<int>> _groups() {
    final p = _c.plan.value;
    final out = <int, List<int>>{};
    if (p == null) return out;
    for (final d in _days) {
      out.putIfAbsent(p.legIndexOf(d), () => []).add(d);
    }
    return out;
  }

  Future<void> _pickTime() async {
    final t = await TemplateTimePopup.pick(context, initial: _time, label: TripStrings.pickupTime, tone: KitTone.taxi);
    if (t != null && mounted) setState(() => _time = t);
  }

  Future<void> _send() async {
    if (_sending || _days.isEmpty) return;
    FocusScope.of(context).unfocus();
    final time = TripFormat.hhmm(_time);
    final place = _place.text.trim();
    setState(() {
      _sending = true;
      _limited = false;
      _limitBody = null;
    });
    final ctrl = TripEnquiryController.to;
    final items = <TripEnquiryModel>[];
    final skipped = <TripSkipped>[];
    final updated = <String>[];
    var short = false;
    int? left;
    for (final group in _groups().values) {
      final batch = await ctrl.sendLead(
        days: group,
        taxiIds: [widget.driver.id],
        pickupTime: time,
        pickupPlace: place.isEmpty ? null : place,
      );
      if (batch == null) break;
      items.addAll(batch.items);
      skipped.addAll(batch.skipped);
      updated.addAll(batch.updated);
      short = short || batch.veryShortNotice;
      left = batch.asksLeft ?? left;
    }
    if (!mounted) return;
    if (items.isEmpty && skipped.isEmpty) {
      final type = ctrl.lastErrorType;
      final limited = type == TripEnquiryErrorTypes.enquiryLimit || type == TripEnquiryErrorTypes.leadLimit;
      setState(() {
        _sending = false;
        _limited = limited;
        _limitBody = type == TripEnquiryErrorTypes.enquiryLimit
            ? TripStrings.askLimitBody(ctrl.lastRetryAfterMinutes ?? 1)
            : (limited ? ctrl.lastErrorMessage : null);
      });
      return;
    }
    Navigator.pop(
      context,
      TripEnquiryBatch(items: items, skipped: skipped, veryShortNotice: short, updated: updated, asksLeft: left),
    );
  }

  static final ListingTone _tone = ListingTone.coral;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = _c.plan.value;
      final s = _c.settings;
      if (p == null) {
        return TripSheetFrame(tone: _tone, art: ListingArt.taxi, title: TripStrings.taxiEnquiry, children: const [SizedBox(height: 24)]);
      }
      if (_days.isEmpty) {
        return TripSheetFrame(
          tone: _tone,
          art: ListingArt.calendar,
          title: TripStringsA3.daysPassedTitle,
          description: TripStringsA3.daysPassedBody,
          footer: WhitePillButton(tone: _tone, label: TripStringsA3.close, onTap: () => Navigator.pop(context)),
          children: const [],
        );
      }
      final from = _c.dateOf(_days.first);
      final to = _c.dateOf(_days.last);
      final left = TripSupplyController.to.asksLeft.value;
      final short = from != null && TripEnquiryRules.enquiryExpiry(s.startDate ?? from, from, DateTime.now().toUtc()).veryShortNotice;
      final limitBody = _limitBody ?? '';
      return TripSheetFrame(
        tone: _tone,
        art: ListingArt.taxi,
        size: SheetSize.form,
        title: TripStrings.taxiEnquiry,
        description: widget.driver.driverName,
        footnote: left == null ? TripStrings.taxiPayLine : TripStrings.asksLeft(left),
        endNote: [TripStrings.taxiEnquiryFooter, if (left != null) TripStrings.taxiPayLine].join(' '),
        footer: GradientPillButton(
          tone: _tone,
          label: TripStrings.sendEnquiry,
          loading: _sending,
          enabled: _days.length <= TripConstants.maxLeadDays,
          onTap: _sending || _days.length > TripConstants.maxLeadDays ? null : _send,
        ),
        children: [
          if (_limited)
            RepliesBanner(
              art: ListingArt.clipboard,
              text: limitBody.isEmpty ? TripStrings.askLimitTitle : '${TripStrings.askLimitTitle}. $limitBody',
              margin: const EdgeInsets.only(bottom: 4),
            ),
          Row(
            children: [
              if (from != null)
                Expanded(child: PillPickerField(tone: _tone, sublabel: TripStrings.from, value: TripFormat.shortDate(from), leadingArt: ListingArt.calendar, trailing: const SizedBox.shrink(), onTap: null)),
              if (from != null && to != null) const SizedBox(width: 10),
              if (to != null)
                Expanded(child: PillPickerField(tone: _tone, sublabel: TripStrings.to, value: TripFormat.shortDate(to), leadingArt: ListingArt.calendar, trailing: const SizedBox.shrink(), onTap: null)),
            ],
          ),
          const SizedBox(height: 12),
          PillPickerField(tone: _tone, sublabel: TripStrings.people, value: s.peopleSummary, hint: TripStrings.addPeople, leadingArt: ListingArt.guests, onTap: () => TripDatesSheet.edit(context)),
          if (short) RepliesBanner(art: ListingArt.calendar, text: TripStringsV2Find.veryShortNoticeDriver, margin: const EdgeInsets.only(top: 12)),
          LayoutBuilder(builder: (context, c) {
            final time = PillPickerField(
              tone: _tone,
              label: TripStrings.pickupTime,
              firstLabel: false,
              value: TripFormat.time12(TripFormat.hhmm(_time)),
              leadingArt: ListingArt.calendar,
              trailing: const SizedBox.shrink(),
              onTap: _sending ? null : _pickTime,
            );
            final place = PillField(
              tone: _tone,
              controller: _place,
              label: TripStrings.pickupPlace,
              firstLabel: false,
              leadingArt: ListingArt.roundPushpin,
              textCapitalization: TextCapitalization.words,
              inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripTaxiEnquirySheet.placeMax)],
            );
            return c.maxWidth >= 320
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: time), const SizedBox(width: 10), Expanded(child: place)])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [time, place]);
          }),
          Padding(padding: const EdgeInsets.only(top: 16, bottom: 6), child: Text(TripStrings.itineraryFromPlan.toUpperCase(), style: RepliesLook.section)),
          for (final n in _days)
            if (p.dayAt(n) != null)
              KeyValueRow(
                label: '${TripStrings.dayN(n)} · ${TripFormat.duration(_c.dayTotalMinutes(n))}',
                value: p.dayAt(n)!.spots.map((x) => x.name).join(' → '),
              ),
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(TripStrings.driverSeesPhone, style: RepliesLook.foot)),
        ],
      );
    });
  }
}
