import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/widgets/trip_ui.dart';
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
import '../widgets/trip_payment_line.dart';
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
    final t = await TemplateTimePopup.pick(context, initial: _time, label: TripStrings.pickupTime, tone: KitTone.trip);
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

  static const _inputStyle = TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 14, color: FitnessAppTheme.darkerText);

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, fontWeight: FontWeight.w600, color: FitnessAppTheme.darkText)),
      );

  Widget _row(String label, String value, {VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.lightText)),
                ),
                Expanded(
                  child: Text(value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w600, color: FitnessAppTheme.darkerText)),
                ),
                if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 18, color: FitnessAppTheme.deactivatedText),
              ],
            ),
          ),
        ),
      );

  Widget _pickup() {
    return LayoutBuilder(builder: (context, c) {
      final time = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(TripStrings.pickupTime),
          InkWell(
            onTap: _sending ? null : _pickTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: FitnessAppTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: FitnessAppTheme.spacer),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 18, color: FitnessAppTheme.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(TripFormat.time12(TripFormat.hhmm(_time)),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: _inputStyle),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
      final place = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(TripStrings.pickupPlace),
          TextField(
            controller: _place,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripTaxiEnquirySheet.placeMax)],
            style: _inputStyle,
            decoration: InputDecoration(
              filled: true,
              fillColor: FitnessAppTheme.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FitnessAppTheme.spacer)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TripUi.trip, width: 1.5)),
            ),
          ),
        ],
      );
      if (c.maxWidth >= 340) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: time),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: place),
          ],
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [time, const SizedBox(height: 12), place]);
    });
  }

  Widget _itinerary() {
    final p = _c.plan.value;
    if (p == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: TripUi.taxiTint, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final n in _days)
            if (p.dayAt(n) != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                    TripStrings.dayLine(n, TripFormat.duration(_c.dayTotalMinutes(n)),
                        p.dayAt(n)!.spots.map((s) => s.name).join(' → ')),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12.5, color: FitnessAppTheme.darkerText, height: 1.35)),
              ),
        ],
      ),
    );
  }

  Widget _limitBanner() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: TripUi.warnTint, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(TripStrings.askLimitTitle,
                style: TextStyle(
                    fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: TripUi.warn)),
            if ((_limitBody ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(_limitBody!,
                  style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: TripUi.warn, height: 1.35)),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final p = _c.plan.value;
      final s = _c.settings;
      if (p == null) {
        return const TripSheetFrame(title: TripStrings.taxiEnquiry, children: [SizedBox(height: 24)]);
      }
      if (_days.isEmpty) {
        return TripSheetFrame(
          title: TripStringsA3.daysPassedTitle,
          description: TripStringsA3.daysPassedBody,
          children: [
            SecondaryButton(label: TripStringsA3.close, tone: KitTone.trip, onPressed: () => Navigator.pop(context)),
          ],
        );
      }
      final from = _c.dateOf(_days.first);
      final to = _c.dateOf(_days.last);
      final left = TripSupplyController.to.asksLeft.value;
      final short = from != null &&
          TripEnquiryRules.enquiryExpiry(s.startDate ?? from, from, DateTime.now().toUtc()).veryShortNotice;
      return TripSheetFrame(
        title: TripStrings.taxiEnquiry,
        description: widget.driver.driverName,
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(TripStrings.taxiEnquiryFooter,
                style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, color: FitnessAppTheme.lightText, height: 1.35)),
            const SizedBox(height: 4),
            const TripPaymentLine(text: TripStrings.taxiPayLine),
            if (left != null) ...[
              const SizedBox(height: 4),
              Text(TripStrings.asksLeft(left),
                  style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, color: FitnessAppTheme.lightText)),
            ],
          ],
        ),
        children: [
          if (_limited) _limitBanner(),
          if (from != null) _row(TripStrings.from, TripFormat.shortDate(from)),
          if (to != null) _row(TripStrings.to, TripFormat.shortDate(to)),
          _row(TripStrings.people, s.peopleSummary ?? TripStrings.addPeople, onTap: () => TripDatesSheet.edit(context)),
          if (short) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: TripUi.warnTint, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: TripUi.warn),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(TripStringsV2Find.veryShortNoticeDriver,
                        style: TextStyle(
                            fontFamily: FitnessAppTheme.fontName, fontSize: 12, fontWeight: FontWeight.w600, color: TripUi.warn)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          _pickup(),
          const SizedBox(height: 16),
          _label(TripStrings.itineraryFromPlan),
          _itinerary(),
          const SizedBox(height: 12),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2),
                child: TravelIcon(TravelIcon.note, size: 18),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(TripStrings.driverSeesPhone,
                    style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: FitnessAppTheme.darkText, height: 1.35)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TripButton(
            label: TripStrings.sendEnquiry,
            height: 52,
            isLoading: _sending,
            gradient: KitTone.trip.gradient,
            shadowColor: TripUi.trip,
            onPressed: _sending || _days.length > TripConstants.maxLeadDays ? null : _send,
          ),
        ],
      );
    });
  }
}
