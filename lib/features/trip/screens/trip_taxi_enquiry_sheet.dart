import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/input_formatters.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/selectable_chip.dart';
import '../../taxi/taxi_option_sets.dart';
import '../controllers/trip_enquiry_controller.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_enquiry_model.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings.dart';
import '../trip_strings_a3.dart';
import '../data/trip_enquiry_repository.dart';
import '../utils/trip_format.dart';
import '../widgets/trip_back_to_plan_bar.dart';
import '../widgets/trip_payment_line.dart';
import '../widgets/trip_sheet_frame.dart';
import 'trip_details_sheet.dart';

class TripTaxiEnquirySheet {
  static int? _asksLeft;

  static bool _bookedByOther(TripPlanController c, int day, Set<String> ids) {
    final booked = c.bookedTaxiEnquiryFor(day);
    if (booked != null) return !ids.contains(booked.listingId);
    final t = c.plan.value?.dayAt(day)?.taxi;
    return t != null && t.isBooked && !t.isOwn && !ids.contains(t.taxiId);
  }

  static List<int> defaultDays(TripPlanController c, int day, {required bool whole, Set<String> taxiIds = const {}}) {
    final all = [for (final d in c.plan.value?.days ?? const <TripDay>[]) d.day];
    final ahead = [for (final d in all) if (!c.isDayPast(d)) d];
    if (ahead.isEmpty) return const [];
    final out = <int>[];
    if (ahead.contains(day) && !_bookedByOther(c, day, taxiIds)) out.add(day);
    if (whole) {
      for (final d in ahead) {
        if (out.length >= TripConstants.maxLeadDays) break;
        if (d != day && !_bookedByOther(c, d, taxiIds)) out.add(d);
      }
    }
    if (out.isEmpty) out.add(ahead.first);
    return out..sort();
  }

  static Future<TripEnquiryBatch?> show(
    BuildContext context, {
    required List<TripTaxiShortlistItem> drivers,
    required int day,
  }) async {
    if (drivers.isEmpty) return null;
    final batch = await TripSheetFrame.show<TripEnquiryBatch>(context, _EnquiryBody(drivers: drivers, day: day));
    if (batch == null) return null;
    _asksLeft = batch.asksLeft ?? _asksLeft;
    final names = {for (final d in drivers) d.taxiId: d.name};
    final skipped = <String>{
      for (final s in batch.skipped)
        if (_reasonText(s.reason) != null) _reasonText(s.reason)!,
    };
    if (batch.items.isEmpty) {
      AppToast.warning(skipped.isEmpty ? TripStringsA3.couldNotSend : skipped.first);
      return batch;
    }
    final updated = batch.updated.toSet();
    final added = batch.items.where((e) => updated.contains(e.id)).toList();
    final fresh = batch.items.length - added.length;
    if (fresh > 0) {
      AppToast.success(batch.items.length == 1 ? TripStrings.enquirySent : TripStringsA3.sentToDrivers(fresh));
    }
    if (added.isNotEmpty) {
      final e = added.first;
      AppToast.success(TripStringsA3.daysAdded(names[e.listingId] ?? e.listingName));
    }
    for (final m in skipped) {
      AppToast.warning(m);
    }
    TripBackToPlanBar.backToPlan();
    return batch;
  }

  static String? _reasonText(String reason) => switch (reason) {
        TripSkipReasons.alreadyOpen => TripStrings.alreadyAsked,
        TripSkipReasons.notAvailable => TripStrings.notAvailableNow,
        TripSkipReasons.blocked => TripStrings.cannotBeAsked,
        TripSkipReasons.limitReached => TripStrings.threeOpen,
        TripSkipReasons.alreadyBooked => TripStringsA3.alreadyBookedOther,
        _ => null,
      };
}

class _EnquiryBody extends StatefulWidget {
  const _EnquiryBody({required this.drivers, required this.day});

  final List<TripTaxiShortlistItem> drivers;
  final int day;

  @override
  State<_EnquiryBody> createState() => _EnquiryBodyState();
}

class _EnquiryBodyState extends State<_EnquiryBody> {
  final _c = TripPlanController.to;
  late final Set<int> _days;
  late final Set<String> _ids;
  late TimeOfDay _time;
  late final TextEditingController _place;
  bool _sending = false;
  bool _limited = false;
  String? _limitBody;

  @override
  void initState() {
    super.initState();
    _ids = {for (final d in widget.drivers) d.taxiId};
    _time = _parseTime(_c.settings.pickupTime) ?? _parseTime(TripConstants.defaultPickupTime)!;
    _days = TripTaxiEnquirySheet.defaultDays(
      _c,
      widget.day,
      whole: widget.drivers.any((d) => d.wholeTrip),
      taxiIds: _ids,
    ).toSet();
    _place = TextEditingController(text: _c.settings.pickupPlace ?? _stayName() ?? '');
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  String? _stayName() {
    if (_days.isEmpty) return null;
    final first = (_days.toList()..sort()).first;
    final stay = _c.plan.value?.dayAt(first)?.stay;
    if (stay == null || stay.isSkipped) return null;
    final name = stay.name.trim();
    return name.isEmpty ? null : name;
  }

  TimeOfDay? _parseTime(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  bool _blocked(int day) => _c.isDayPast(day) || TripTaxiEnquirySheet._bookedByOther(_c, day, _ids);

  void _toggle(int day) {
    if (_sending || _blocked(day)) return;
    if (_days.contains(day)) {
      if (_days.length == 1) {
        AppToast.warning(TripStrings.errPickDay);
        return;
      }
      setState(() => _days.remove(day));
    } else {
      if (_days.length >= TripConstants.maxLeadDays) return;
      setState(() => _days.add(day));
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null && mounted) setState(() => _time = t);
  }

  Future<void> _send() async {
    if (_sending || _days.isEmpty) return;
    FocusScope.of(context).unfocus();
    final days = _days.toList()..sort();
    final time = TripFormat.hhmm(_time);
    final place = _place.text.trim();
    final s = _c.settings;
    setState(() {
      _sending = true;
      _limited = false;
      _limitBody = null;
    });
    if (s.pickupTime != time || (s.pickupPlace ?? '') != place) {
      await _c.saveSettings(s.copyWith(pickupTime: time, pickupPlace: place.isEmpty ? null : place));
    }
    final ctrl = TripEnquiryController.to;
    final batch = await ctrl.sendLead(
      days: days,
      taxiIds: widget.drivers.map((d) => d.taxiId).toList(),
      pickupTime: time,
      pickupPlace: place.isEmpty ? null : place,
    );
    if (!mounted) return;
    if (batch == null) {
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
    Navigator.pop(context, batch);
  }

  static const _inputStyle = TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppColors.textDark);

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
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
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                ),
                Expanded(
                  child: Text(value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                ),
                if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
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
                color: AppColors.scaffoldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.clock, size: 16, color: TripColors.accent),
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
            inputFormatters: [...noEmojiInputFormatters, LengthLimitingTextInputFormatter(TripConstants.pickupPlaceMax)],
            style: _inputStyle,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.scaffoldBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TripColors.accent, width: 1.5)),
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

  Widget _daysWrap(List<TripDay> days) {
    final full = _days.length >= TripConstants.maxLeadDays;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in days)
          Builder(builder: (_) {
            final on = _days.contains(d.day);
            final date = _c.dateOf(d.day);
            final label = date == null ? TripStrings.dayN(d.day) : '${TripStrings.dayN(d.day)} · ${TripFormat.shortDate(date)}';
            final disabled = _blocked(d.day) || (!on && full);
            return Opacity(
              opacity: disabled ? 0.4 : 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: SelectableChip(
                  label: label,
                  selected: on,
                  onTap: () => _toggle(d.day),
                  activeColor: TripColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _itinerary(List<TripDay> chosen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: TaxiColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in chosen)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                  TripStrings.dayLine(d.day, TripFormat.duration(_c.dayTotalMinutes(d.day)), d.spots.map((s) => s.name).join(' → ')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: AppColors.textDark, height: 1.35)),
            ),
        ],
      ),
    );
  }

  Widget _limitBanner() => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(TripStrings.askLimitTitle,
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.warningText)),
            if ((_limitBody ?? '').isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(_limitBody!,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.warningText, height: 1.35)),
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
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: AppColors.divider),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(TripStringsA3.close,
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: TripColors.accentDark)),
            ),
          ],
        );
      }
      final sorted = _days.toList()..sort();
      final from = _c.dateOf(sorted.first);
      final to = _c.dateOf(sorted.last);
      final chosen = [for (final d in p.days) if (_days.contains(d.day)) d];
      final left = TripTaxiEnquirySheet._asksLeft;
      return TripSheetFrame(
        title: TripStrings.taxiEnquiry,
        description: widget.drivers.length == 1 ? widget.drivers.first.name : TripStringsA3.driversTitle(widget.drivers.length),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(TripStrings.taxiEnquiryFooter,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, height: 1.35)),
            const SizedBox(height: 4),
            const TripPaymentLine(text: TripStrings.taxiPayLine),
            if (left != null) ...[
              const SizedBox(height: 4),
              Text(TripStrings.asksLeft(left),
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
            ],
          ],
        ),
        children: [
          if (_limited) _limitBanner(),
          if (from != null) _row(TripStrings.from, TripFormat.shortDate(from)),
          if (to != null) _row(TripStrings.to, TripFormat.shortDate(to)),
          _row(TripStrings.people, s.peopleSummary ?? TripStrings.addPeople, onTap: () => TripDetailsSheet.edit(context)),
          const SizedBox(height: 8),
          _pickup(),
          const SizedBox(height: 16),
          _label(TripStrings.daysToInclude),
          _daysWrap(p.days),
          const SizedBox(height: 16),
          _label(TripStrings.itineraryFromPlan),
          _itinerary(chosen),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Iconsax.info_circle, size: 16, color: AppColors.textLight),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(TripStrings.driverSeesPhone,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium, height: 1.35)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: TripStrings.sendEnquiry,
            height: 52,
            isLoading: _sending,
            gradient: TripColors.gradient,
            shadowColor: TripColors.accent,
            onPressed: _sending ? null : _send,
          ),
        ],
      );
    });
  }
}
